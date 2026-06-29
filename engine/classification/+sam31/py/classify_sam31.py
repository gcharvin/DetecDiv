from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image
from scipy.io import loadmat, savemat

PREDICTOR = None
PREDICTOR_KEY = None


def as_local_path(value: str | Path | None) -> Path | None:
    if value is None:
        return None
    text = str(value)
    if not text:
        return None
    if platform.system() == "Linux" and len(text) >= 3 and text[1:3] in {":\\", ":/"}:
        drive = text[0].lower()
        rest = text[2:].replace("\\", "/")
        return Path(f"/mnt/{drive}{rest}")
    return Path(text).expanduser()


def optional_path(value: str | None) -> Path | None:
    path = as_local_path(value)
    if path is None or not str(path):
        return None
    return path


def classifier_root_from_output_dir(output_dir: Path) -> Path | None:
    # DetecDiv classifier inference work dirs are usually
    # <classifier>/work/sam31/<roi-id>. Keep this best-effort so standalone
    # configs still work when explicit checkpoint paths are provided.
    parts = output_dir.resolve().parts
    if len(parts) >= 4 and parts[-2] == "sam31" and parts[-3] == "work":
        return Path(*parts[:-3])
    return None


def resolve_importable_repo_root(repo_root: Path) -> Path:
    if (repo_root / "sam31_ctc_benchmark").is_dir():
        return repo_root
    candidates = [
        Path("/mnt/c/Users/Gilles/Documents/MATLAB/SAM31_yeast"),
        Path("/mnt/c/Users/Gilles/Documents/MATLAB/SAM31_zero_shot_ctc_benchmark"),
        Path("/home/gilles/repos/SAM31_zero_shot_ctc_benchmark"),
        Path("/home/charvin-admin/repos/SAM31_zero_shot_ctc_benchmark"),
        Path("/data/Gilles/SAM31_zero_shot_ctc_benchmark"),
    ]
    for candidate in candidates:
        if (candidate / "sam31_ctc_benchmark").is_dir():
            print(f"[SAM31 classify] using importable repo_root: {candidate}", flush=True)
            return candidate
    return repo_root


def newest_existing(paths: list[Path]) -> Path | None:
    existing = [path for path in paths if path.exists()]
    if not existing:
        return None
    return max(existing, key=lambda path: path.stat().st_mtime)


def latest_checkpoint(classifier_root: Path | None, image_size: int, kind: str) -> Path | None:
    if classifier_root is None:
        return None
    artifacts = classifier_root / "sam31_artifacts"
    if kind == "detector":
        direct = artifacts / f"moma_sam31_image_instance_prompt_scoring_encoder_{image_size}" / "checkpoints" / "checkpoint.pt"
        patterns = [
            f"moma_sam31_image_instance*_{image_size}/checkpoints/checkpoint.pt",
            "moma_sam31_image_instance*/checkpoints/checkpoint.pt",
        ]
    elif kind == "tracker":
        direct = artifacts / f"moma_sam31_tracklet_len8_head_only_{image_size}" / "checkpoints" / "checkpoint.pt"
        patterns = [
            f"moma_sam31_tracklet*_{image_size}/checkpoints/checkpoint.pt",
            "moma_sam31_tracklet*/checkpoints/checkpoint.pt",
        ]
    else:
        raise ValueError(f"Unknown checkpoint kind: {kind}")

    candidates = [direct]
    for pattern in patterns:
        candidates.extend(artifacts.glob(pattern))
    return newest_existing(candidates)


def resolve_checkpoint(value: str | None, output_dir: Path, image_size: int, kind: str) -> Path | None:
    explicit = optional_path(value)
    if explicit is not None:
        return explicit
    resolved = latest_checkpoint(classifier_root_from_output_dir(output_dir), image_size, kind)
    if resolved is not None:
        print(f"[SAM31 classify] using auto {kind} checkpoint: {resolved}", flush=True)
    return resolved


def scalar_number(value: Any, default: float, name: str, *, integer: bool = False, minimum: float | None = None) -> int | float:
    if value is None:
        out = float(default)
    elif isinstance(value, (list, tuple)):
        if not value:
            out = float(default)
        else:
            print(
                f"[SAM31 classify] warning: {name} must be scalar; using first value {value[0]!r} from {value!r}",
                flush=True,
            )
            out = scalar_number(value[0], default, name, integer=False, minimum=None)
    else:
        text = str(value).strip()
        try:
            out = float(text)
        except ValueError:
            if "," in text and "." not in text:
                out = float(text.replace(",", "."))
            else:
                raise ValueError(f"{name} must be numeric, got {value!r}") from None

    if not np.isfinite(out):
        raise ValueError(f"{name} must be finite, got {value!r}")
    if minimum is not None and out < minimum:
        raise ValueError(f"{name} must be >= {minimum}, got {out!r}")
    if integer:
        return int(round(out))
    return float(out)


def is_cancel_requested(cancel_path: Path | None) -> bool:
    return cancel_path is not None and cancel_path.exists()


def check_cancel(cancel_path: Path | None, where: str) -> None:
    if is_cancel_requested(cancel_path):
        raise SystemExit(f"DetecDiv run cancelled during SAM31 classify ({where}).")


def robust_u8(image: np.ndarray) -> np.ndarray:
    arr = np.asarray(image, dtype=np.float32)
    lo, hi = np.percentile(arr, [1.0, 99.8])
    if not np.isfinite(lo) or not np.isfinite(hi) or hi <= lo:
        lo, hi = float(arr.min()), float(arr.max())
    if hi <= lo:
        return np.zeros(arr.shape, dtype=np.uint8)
    arr = np.clip((arr - lo) / (hi - lo), 0.0, 1.0)
    return np.round(arr * 255).astype(np.uint8)


def load_raw_stack(path: Path) -> tuple[np.ndarray, np.ndarray]:
    mat = loadmat(path)
    if "raw" not in mat:
        raise ValueError(f"{path} has no raw variable")
    raw = np.asarray(mat["raw"])
    frames = np.asarray(mat.get("frames", np.arange(1, raw.shape[-1] + 1))).reshape(-1)
    raw = np.squeeze(raw)
    if raw.ndim == 2:
        raw = raw[:, :, None]
    if raw.ndim == 3:
        raw = raw[:, :, None, :]
    if raw.ndim != 4:
        raise ValueError(f"Expected raw as [H,W,C,T], got {raw.shape}")
    return raw, frames.astype(np.int64)


def write_image_sequence(raw: np.ndarray, image_dir: Path, cancel_path: Path | None = None) -> None:
    if image_dir.exists():
        shutil.rmtree(image_dir)
    image_dir.mkdir(parents=True, exist_ok=True)
    for frame_idx in range(raw.shape[3]):
        if frame_idx % 10 == 0:
            check_cancel(cancel_path, f"write frame {frame_idx + 1}/{raw.shape[3]}")
        plane = raw[:, :, 0, frame_idx]
        gray = robust_u8(plane)
        rgb = np.repeat(gray[:, :, None], 3, axis=2)
        Image.fromarray(rgb).save(image_dir / f"{frame_idx:05d}.png")


def resize_labels_nearest(labels: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    if tuple(labels.shape) == tuple(shape):
        return labels.astype(np.uint16, copy=False)
    image = Image.fromarray(labels.astype(np.uint16))
    image = image.resize((shape[1], shape[0]), resample=Image.Resampling.NEAREST)
    return np.asarray(image, dtype=np.uint16)


def link_or_copy(src: Path, dst: Path) -> None:
    try:
        os.symlink(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def instance_masks(labels: np.ndarray) -> dict[int, np.ndarray]:
    return {int(label): labels == label for label in np.unique(labels) if label != 0}


def label_iou(mask_a: np.ndarray, mask_b: np.ndarray) -> float:
    inter = np.logical_and(mask_a, mask_b).sum()
    union = np.logical_or(mask_a, mask_b).sum()
    return float(inter / union) if union else 0.0


def max_weight_assignment(score_matrix: np.ndarray) -> list[tuple[int, int]]:
    if score_matrix.size == 0:
        return []
    try:
        from scipy.optimize import linear_sum_assignment

        rows, cols = linear_sum_assignment(-score_matrix)
        return [(int(r), int(c)) for r, c in zip(rows, cols) if score_matrix[r, c] > 0]
    except Exception:
        remaining_rows = set(range(score_matrix.shape[0]))
        remaining_cols = set(range(score_matrix.shape[1]))
        pairs: list[tuple[int, int]] = []
        while remaining_rows and remaining_cols:
            best = None
            best_score = 0.0
            for row in remaining_rows:
                for col in remaining_cols:
                    score = float(score_matrix[row, col])
                    if score > best_score:
                        best = (row, col)
                        best_score = score
            if best is None:
                break
            pairs.append(best)
            remaining_rows.remove(best[0])
            remaining_cols.remove(best[1])
        return pairs


def stitch_chunk_ids(
    global_labels: list[np.ndarray | None],
    local_labels: list[np.ndarray],
    chunk_start: int,
    next_global_id: int,
    overlap_iou_threshold: float = 0.25,
) -> tuple[list[np.ndarray | None], int]:
    local_ids = sorted({int(label) for labels in local_labels for label in np.unique(labels) if label != 0})
    if not local_ids:
        for local_idx, labels in enumerate(local_labels):
            abs_idx = chunk_start + local_idx
            if global_labels[abs_idx] is None:
                global_labels[abs_idx] = np.zeros_like(labels, dtype=np.uint16)
        return global_labels, next_global_id

    global_ids = sorted(
        {
            int(label)
            for local_idx in range(len(local_labels))
            if global_labels[chunk_start + local_idx] is not None
            for label in np.unique(global_labels[chunk_start + local_idx])
            if label != 0
        }
    )
    local_index = {obj_id: idx for idx, obj_id in enumerate(local_ids)}
    global_index = {obj_id: idx for idx, obj_id in enumerate(global_ids)}
    scores = np.zeros((len(local_ids), len(global_ids)), dtype=np.float32)

    for local_idx, local_frame in enumerate(local_labels):
        abs_idx = chunk_start + local_idx
        existing = global_labels[abs_idx]
        if existing is None:
            continue
        local_masks = instance_masks(local_frame)
        global_masks = instance_masks(existing)
        for local_id, local_mask in local_masks.items():
            for global_id, global_mask in global_masks.items():
                scores[local_index[int(local_id)], global_index[int(global_id)]] += label_iou(local_mask, global_mask)

    local_to_global: dict[int, int] = {}
    for local_row, global_col in max_weight_assignment(scores):
        if scores[local_row, global_col] >= overlap_iou_threshold:
            local_to_global[local_ids[local_row]] = global_ids[global_col]
    for local_id in local_ids:
        if local_id not in local_to_global:
            local_to_global[local_id] = next_global_id
            next_global_id += 1

    for local_idx, local_frame in enumerate(local_labels):
        abs_idx = chunk_start + local_idx
        if global_labels[abs_idx] is not None:
            continue
        remapped = np.zeros_like(local_frame, dtype=np.uint16)
        for local_id, global_id in local_to_global.items():
            remapped[local_frame == local_id] = global_id
        global_labels[abs_idx] = remapped
    return global_labels, next_global_id


def no_points_error(exc: Exception) -> bool:
    text = str(exc)
    return "No points are provided" in text or "please add points first" in text


def run_sam31_text_movie_once(
    predictor,
    image_dir: Path,
    num_frames: int,
    prompt: str,
    min_score: float,
    fallback_shape: tuple[int, int],
    cancel_path: Path | None = None,
):
    from sam31_ctc_benchmark.sam31_runner import output_to_label_mask, propagate_in_video

    check_cancel(cancel_path, "before start_session")
    response = predictor.handle_request(request={"type": "start_session", "resource_path": str(image_dir)})
    session_id = response["session_id"]
    try:
        predictor.handle_request(request={"type": "reset_session", "session_id": session_id})
        check_cancel(cancel_path, "before prompt")
        predictor.handle_request(
            request={
                "type": "add_prompt",
                "session_id": session_id,
                "frame_index": 0,
                "text": prompt,
                "output_prob_thresh": min_score,
            }
        )
        check_cancel(cancel_path, "before propagation")
        outputs = propagate_in_video(predictor, session_id, output_prob_thresh=min_score)
        check_cancel(cancel_path, "after propagation")
        labels_by_frame: list[np.ndarray] = []
        stats_by_frame: list[dict] = []
        for frame_idx in range(num_frames):
            if frame_idx % 10 == 0:
                check_cancel(cancel_path, f"label frame {frame_idx + 1}/{num_frames}")
            output = outputs.get(frame_idx)
            if output is None:
                labels_by_frame.append(np.zeros(fallback_shape, dtype=np.uint16))
                stats_by_frame.append({"frame_index": frame_idx, "missing_output": True})
                continue
            labels = output_to_label_mask(output, min_score=min_score)
            labels_by_frame.append(labels)
            stats = dict(output.get("frame_stats") or {})
            stats["frame_index"] = frame_idx
            stats["num_output_objects"] = int(labels.max())
            stats_by_frame.append(stats)
        return labels_by_frame, stats_by_frame
    finally:
        predictor.handle_request(request={"type": "close_session", "session_id": session_id})


def run_sam31_text_movie_chunked(
    predictor,
    image_dir: Path,
    num_frames: int,
    prompt: str,
    min_score: float,
    fallback_shape: tuple[int, int],
    chunk_size: int,
    chunk_overlap: int,
    cancel_path: Path | None = None,
):
    file_names = [f"{idx:05d}.png" for idx in range(num_frames)]
    if chunk_overlap >= chunk_size:
        raise ValueError("chunk_overlap must be smaller than chunk_size")

    global_labels: list[np.ndarray | None] = [None] * num_frames
    global_stats: list[dict | None] = [None] * num_frames
    next_global_id = 1
    start = 0
    while start < num_frames:
        check_cancel(cancel_path, f"chunk {start + 1}/{num_frames}")
        end = min(num_frames, start + chunk_size)
        print(f"[SAM31 classify] chunk {start:03d}:{end:03d}", flush=True)
        with tempfile.TemporaryDirectory(prefix="detecdiv_sam31_chunk_") as tmp:
            chunk_dir = Path(tmp)
            for local_idx, frame_name in enumerate(file_names[start:end]):
                link_or_copy(image_dir / frame_name, chunk_dir / f"{local_idx:05d}.png")
            try:
                local_labels, local_stats = run_sam31_text_movie_once(
                    predictor=predictor,
                    image_dir=chunk_dir,
                    num_frames=end - start,
                    prompt=prompt,
                    min_score=min_score,
                    fallback_shape=fallback_shape,
                    cancel_path=cancel_path,
                )
            except RuntimeError as exc:
                if not no_points_error(exc):
                    raise
                print(
                    f"[SAM31 classify] chunk {start:03d}:{end:03d} produced no tracker points; "
                    "writing empty masks for this chunk.",
                    flush=True,
                )
                local_labels = [np.zeros(fallback_shape, dtype=np.uint16) for _ in range(end - start)]
                local_stats = [
                    {"frame_index": local_idx, "missing_tracker_points": True}
                    for local_idx in range(end - start)
                ]

        global_labels, next_global_id = stitch_chunk_ids(
            global_labels=global_labels,
            local_labels=local_labels,
            chunk_start=start,
            next_global_id=next_global_id,
        )
        for local_idx, stats in enumerate(local_stats):
            abs_idx = start + local_idx
            if global_stats[abs_idx] is None:
                row = dict(stats)
                row["frame_index"] = abs_idx
                row["chunk_start"] = start
                row["chunk_end"] = end
                global_stats[abs_idx] = row
        if end == num_frames:
            break
        start = end - chunk_overlap

    labels = [
        np.zeros(fallback_shape, dtype=np.uint16) if labels is None else labels
        for labels in global_labels
    ]
    stats = [
        {"frame_index": idx, "missing_output": True} if row is None else row
        for idx, row in enumerate(global_stats)
    ]
    return labels, stats


def run_sam31_text_movie(
    predictor,
    image_dir: Path,
    num_frames: int,
    prompt: str,
    min_score: float,
    fallback_shape: tuple[int, int],
    chunk_size: int = 0,
    chunk_overlap: int = 0,
    cancel_path: Path | None = None,
):
    if chunk_size > 0 and chunk_size < num_frames:
        return run_sam31_text_movie_chunked(
            predictor=predictor,
            image_dir=image_dir,
            num_frames=num_frames,
            prompt=prompt,
            min_score=min_score,
            fallback_shape=fallback_shape,
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            cancel_path=cancel_path,
        )

    try:
        return run_sam31_text_movie_once(
            predictor=predictor,
            image_dir=image_dir,
            num_frames=num_frames,
            prompt=prompt,
            min_score=min_score,
            fallback_shape=fallback_shape,
            cancel_path=cancel_path,
        )
    except RuntimeError as exc:
        if not no_points_error(exc) or num_frames <= 1:
            raise
        fallback_chunk_size = min(32, num_frames)
        fallback_overlap = min(4, max(0, fallback_chunk_size - 1))
        print(
            "[SAM31 classify] full-session propagation lost tracker points; "
            f"retrying with chunk_size={fallback_chunk_size}, chunk_overlap={fallback_overlap}.",
            flush=True,
        )
        return run_sam31_text_movie_chunked(
            predictor=predictor,
            image_dir=image_dir,
            num_frames=num_frames,
            prompt=prompt,
            min_score=min_score,
            fallback_shape=fallback_shape,
            chunk_size=fallback_chunk_size,
            chunk_overlap=fallback_overlap,
            cancel_path=cancel_path,
        )


def predictor_cache_key(
    detector_checkpoint_path: Path | None,
    tracker_checkpoint_path: Path | None,
    image_size: int,
    video_kwargs: dict[str, Any],
) -> tuple:
    return (
        str(detector_checkpoint_path.resolve()) if detector_checkpoint_path is not None else "",
        str(tracker_checkpoint_path.resolve()) if tracker_checkpoint_path is not None else "",
        int(image_size),
        tuple(sorted((str(k), str(v)) for k, v in video_kwargs.items())),
    )


def get_predictor(
    detector_checkpoint_path: Path | None,
    tracker_checkpoint_path: Path | None,
    image_size: int,
    video_kwargs: dict[str, Any],
):
    global PREDICTOR, PREDICTOR_KEY

    key = predictor_cache_key(
        detector_checkpoint_path=detector_checkpoint_path,
        tracker_checkpoint_path=tracker_checkpoint_path,
        image_size=image_size,
        video_kwargs=video_kwargs,
    )
    if PREDICTOR is not None and PREDICTOR_KEY == key:
        print("[SAM31 classify] reusing cached SAM31 predictor", flush=True)
        return PREDICTOR

    from sam31_ctc_benchmark.sam31_runner import build_predictor  # noqa: WPS433

    print("[SAM31 classify] loading SAM31 predictor", flush=True)
    PREDICTOR = build_predictor(
        detector_checkpoint_path=detector_checkpoint_path,
        tracker_checkpoint_path=tracker_checkpoint_path,
        image_size=image_size,
        video_kwargs=video_kwargs,
    )
    PREDICTOR_KEY = key
    return PREDICTOR


def run(config_path: str | Path) -> None:
    cfg = json.loads(Path(config_path).read_text(encoding="utf-8"))
    repo_root = as_local_path(cfg["repo_root"])
    sam3_repo = as_local_path(cfg["sam3_repo"])
    input_mat_path = as_local_path(cfg["input_mat_path"])
    output_dir = as_local_path(cfg["output_dir"])
    cancel_path = as_local_path(cfg.get("cancel_path"))
    if repo_root is None or sam3_repo is None or input_mat_path is None or output_dir is None:
        raise SystemExit("Missing repo_root, sam3_repo, input_mat_path, or output_dir")
    repo_root = resolve_importable_repo_root(repo_root)
    if not sam3_repo.exists():
        candidate = repo_root / "artifacts" / "sam3_official"
        if candidate.exists():
            sam3_repo = candidate
    check_cancel(cancel_path, "startup")

    sys.path.insert(0, str(repo_root))
    sys.path.insert(0, str(repo_root / "scripts"))
    sys.path.insert(0, str(sam3_repo))

    raw, frames = load_raw_stack(input_mat_path)
    image_dir = output_dir / "sam31_images"
    write_image_sequence(raw, image_dir, cancel_path=cancel_path)
    check_cancel(cancel_path, "after image export")

    if bool(cfg.get("smoke_only", False)):
        height, width = raw.shape[0], raw.shape[1]
        masks = np.zeros((height, width, 1, raw.shape[3]), dtype=np.uint16)
        output_dir.mkdir(parents=True, exist_ok=True)
        savemat(
            output_dir / "results.mat",
            {
                "masks_all": masks,
                "frames_list": frames.reshape(1, -1),
            },
            do_compression=True,
        )
        (output_dir / "sam31_stats.json").write_text(
            json.dumps({"smoke_only": True, "frames": int(raw.shape[3])}, indent=2),
            encoding="utf-8",
        )
        return

    video_kwargs = {
        "score_threshold_detection": scalar_number(cfg.get("video_score_threshold"), 0.40, "video_score_threshold", minimum=0.0),
        "new_det_thresh": scalar_number(cfg.get("video_new_det_threshold"), 0.40, "video_new_det_threshold", minimum=0.0),
        "det_nms_thresh": scalar_number(cfg.get("video_det_nms_threshold"), 0.10, "video_det_nms_threshold", minimum=0.0),
        "assoc_iou_thresh": scalar_number(cfg.get("video_assoc_iou_threshold"), 0.50, "video_assoc_iou_threshold", minimum=0.0),
        "max_num_objects": scalar_number(cfg.get("max_num_objects"), 40, "max_num_objects", integer=True, minimum=1.0),
    }
    video_kwargs = {k: v for k, v in video_kwargs.items() if v is not None}
    image_size = scalar_number(cfg.get("image_size"), 280, "image_size", integer=True, minimum=1.0)
    detector_checkpoint_path = resolve_checkpoint(
        cfg.get("detector_checkpoint_path"),
        output_dir=output_dir,
        image_size=image_size,
        kind="detector",
    )
    tracker_checkpoint_path = resolve_checkpoint(
        cfg.get("tracker_checkpoint_path"),
        output_dir=output_dir,
        image_size=image_size,
        kind="tracker",
    )
    predictor = get_predictor(
        detector_checkpoint_path=detector_checkpoint_path,
        tracker_checkpoint_path=tracker_checkpoint_path,
        image_size=image_size,
        video_kwargs=video_kwargs,
    )
    labels_by_frame, stats_by_frame = run_sam31_text_movie(
        predictor=predictor,
        image_dir=image_dir,
        num_frames=raw.shape[3],
        prompt=str(cfg.get("prompt", "cell")),
        min_score=scalar_number(cfg.get("min_score"), 0.0, "min_score", minimum=0.0),
        fallback_shape=(raw.shape[0], raw.shape[1]),
        chunk_size=scalar_number(cfg.get("chunk_size"), 0, "chunk_size", integer=True, minimum=0.0),
        chunk_overlap=scalar_number(cfg.get("chunk_overlap"), 0, "chunk_overlap", integer=True, minimum=0.0),
        cancel_path=cancel_path,
    )

    height, width = raw.shape[0], raw.shape[1]
    masks = np.zeros((height, width, 1, len(labels_by_frame)), dtype=np.uint16)
    for idx, labels in enumerate(labels_by_frame):
        if idx % 10 == 0:
            check_cancel(cancel_path, f"mask frame {idx + 1}/{len(labels_by_frame)}")
        masks[:, :, 0, idx] = resize_labels_nearest(labels, (height, width))

    output_dir.mkdir(parents=True, exist_ok=True)
    savemat(
        output_dir / "results.mat",
        {
            "masks_all": masks,
            "frames_list": frames.reshape(1, -1),
        },
        do_compression=True,
    )
    (output_dir / "sam31_stats.json").write_text(
        json.dumps({"frames": len(labels_by_frame), "stats_by_frame": stats_by_frame}, indent=2, default=str),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="DetecDiv bridge for SAM31 ROI inference.")
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    run(args.config)


if __name__ == "__main__":
    main()
