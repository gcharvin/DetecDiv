from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import sys
import tempfile
import time
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
        ]
        fallback_patterns = ["moma_sam31_image_instance*/checkpoints/checkpoint.pt"]
    elif kind == "tracker":
        direct = artifacts / f"moma_sam31_tracklet_len8_head_only_{image_size}" / "checkpoints" / "checkpoint.pt"
        patterns = [
            f"moma_sam31_tracklet*_{image_size}/checkpoints/checkpoint.pt",
        ]
        fallback_patterns = ["moma_sam31_tracklet*/checkpoints/checkpoint.pt"]
    else:
        raise ValueError(f"Unknown checkpoint kind: {kind}")

    exact_candidates = [direct]
    for pattern in patterns:
        exact_candidates.extend(artifacts.glob(pattern))
    resolved = newest_existing(exact_candidates)
    if resolved is not None:
        return resolved

    fallback_candidates: list[Path] = []
    for pattern in fallback_patterns:
        fallback_candidates.extend(artifacts.glob(pattern))
    resolved = newest_existing(fallback_candidates)
    if resolved is not None:
        print(
            f"[SAM31 classify] warning: no {kind} checkpoint found for image_size={image_size}; "
            f"falling back to {resolved}",
            flush=True,
        )
    return resolved


def resolve_checkpoint(
    value: str | None,
    output_dir: Path,
    image_size: int,
    kind: str,
    search_roots: list[Path] | None = None,
) -> Path | None:
    explicit = optional_path(value)
    if explicit is not None:
        print(f"[SAM31 classify] using explicit {kind} checkpoint: {explicit}", flush=True)
        return explicit
    resolved = latest_checkpoint(classifier_root_from_output_dir(output_dir), image_size, kind)
    if resolved is not None:
        print(f"[SAM31 classify] using auto {kind} checkpoint: {resolved}", flush=True)
        return resolved
    for root in search_roots or []:
        resolved = latest_checkpoint(root, image_size, kind)
        if resolved is not None:
            print(f"[SAM31 classify] using searched {kind} checkpoint: {resolved}", flush=True)
            return resolved
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


def bool_value(value: Any, default: bool = False) -> bool:
    if value is None:
        return bool(default)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float, np.integer, np.floating)):
        return bool(value)
    text = str(value).strip().lower()
    if text in {"1", "true", "yes", "on", "oui"}:
        return True
    if text in {"0", "false", "no", "off", "non"}:
        return False
    return bool(default)


def is_cancel_requested(cancel_path: Path | None) -> bool:
    return cancel_path is not None and cancel_path.exists()


def check_cancel(cancel_path: Path | None, where: str) -> None:
    if is_cancel_requested(cancel_path):
        raise SystemExit(f"DetecDiv run cancelled during SAM31 classify ({where}).")


def output_object_counts(output: dict[str, Any], min_score: float = 0.0) -> tuple[int, int]:
    obj_ids = output.get("out_obj_ids")
    if obj_ids is None:
        return 0, 0
    if hasattr(obj_ids, "detach"):
        obj_ids = obj_ids.detach().cpu().numpy()
    obj_ids_arr = np.asarray(obj_ids).reshape(-1)
    raw_count = int(obj_ids_arr.size)

    scores = output.get("out_probs")
    if scores is None:
        return raw_count, raw_count
    if hasattr(scores, "detach"):
        scores = scores.detach().cpu().numpy()
    scores_arr = np.asarray(scores, dtype=np.float32).reshape(-1)
    if scores_arr.size != raw_count:
        return raw_count, raw_count
    kept_count = int(np.count_nonzero(scores_arr >= float(min_score)))
    return raw_count, kept_count


def stream_propagate_in_video(
    predictor,
    session_id: str,
    *,
    total_frames: int,
    min_score: float,
    cancel_path: Path | None = None,
    prefix: str = "[SAM31 PY]",
) -> dict[int, dict]:
    outputs_per_frame: dict[int, dict] = {}
    start_time = time.time()
    last_log = 0.0
    seen = 0
    print(f"{prefix} Propagation start ({total_frames} frames)", flush=True)
    for response in predictor.handle_stream_request(
        request={
            "type": "propagate_in_video",
            "session_id": session_id,
            "output_prob_thresh": min_score,
        }
    ):
        check_cancel(cancel_path, f"propagate frame {seen + 1}/{total_frames}")
        frame_idx = int(response["frame_index"])
        output = response["outputs"]
        outputs_per_frame[frame_idx] = output
        seen += 1

        raw_count, kept_count = output_object_counts(output, min_score=min_score)
        elapsed = max(time.time() - start_time, 1e-6)
        fps = seen / elapsed
        remaining = max(total_frames - seen, 0)
        eta = remaining / fps if fps > 0 else float("nan")
        now = time.time()
        should_log = (
            seen == 1
            or seen == total_frames
            or seen % 5 == 0
            or now - last_log >= 5.0
        )
        if should_log:
            print(
                f"{prefix} Frame {seen}/{total_frames} done "
                f"(frame_index={frame_idx + 1}, objects={kept_count}, raw_objects={raw_count}, "
                f"{fps:.2f} frame/s, ETA {eta:.1f}s)",
                flush=True,
            )
            last_log = now
    elapsed = max(time.time() - start_time, 1e-6)
    print(
        f"{prefix} Propagation done ({seen}/{total_frames} frames, {seen / elapsed:.2f} frame/s)",
        flush=True,
    )
    return outputs_per_frame


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
        remapped = np.zeros_like(local_frame, dtype=np.uint16)
        for local_id, global_id in local_to_global.items():
            remapped[local_frame == local_id] = global_id
        existing = global_labels[abs_idx]
        if existing is not None:
            existing_pixels = int(np.count_nonzero(existing))
            remapped_pixels = int(np.count_nonzero(remapped))
            existing_labels = len([label for label in np.unique(existing) if label != 0])
            remapped_labels = len([label for label in np.unique(remapped) if label != 0])
            enough_labels = remapped_labels >= max(2, int(0.5 * max(existing_labels, 1)))
            enough_pixels = remapped_pixels > max(existing_pixels * 1.25, existing_pixels + 1024)
            if not (enough_pixels and enough_labels):
                continue
        global_labels[abs_idx] = remapped
    return global_labels, next_global_id


def frame_local_instance_labels(labels_by_frame: list[np.ndarray]) -> list[np.ndarray]:
    """Drop temporal identity and keep frame-local instance labels."""
    remapped_frames: list[np.ndarray] = []
    for frame in labels_by_frame:
        out = np.zeros_like(frame, dtype=np.uint16)
        labels = [int(label) for label in np.unique(frame) if label != 0]
        for new_id, old_id in enumerate(labels, start=1):
            out[frame == old_id] = new_id
        remapped_frames.append(out)
    return remapped_frames


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
    from sam31_ctc_benchmark.sam31_runner import output_to_label_mask

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
        outputs = stream_propagate_in_video(
            predictor,
            session_id,
            total_frames=num_frames,
            min_score=min_score,
            cancel_path=cancel_path,
            prefix="[SAM31 PY]",
        )
        check_cancel(cancel_path, "after propagation")
        labels_by_frame: list[np.ndarray] = []
        stats_by_frame: list[dict] = []
        final_counts: list[int] = []
        for frame_idx in range(num_frames):
            if frame_idx % 10 == 0:
                check_cancel(cancel_path, f"label frame {frame_idx + 1}/{num_frames}")
            output = outputs.get(frame_idx)
            if output is None:
                labels_by_frame.append(np.zeros(fallback_shape, dtype=np.uint16))
                stats_by_frame.append({"frame_index": frame_idx, "missing_output": True})
                final_counts.append(0)
                continue
            labels = output_to_label_mask(output, min_score=min_score)
            labels_by_frame.append(labels)
            final_count = len([label for label in np.unique(labels) if label != 0])
            final_counts.append(int(final_count))
            stats = dict(output.get("frame_stats") or {})
            stats["frame_index"] = frame_idx
            stats["num_output_objects"] = int(final_count)
            stats_by_frame.append(stats)
        if final_counts:
            print(
                "[SAM31 PY] Final mask objects per frame: "
                f"min={min(final_counts)}, median={float(np.median(final_counts)):.1f}, "
                f"max={max(final_counts)}, first={final_counts[0]}, last={final_counts[-1]}",
                flush=True,
            )
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


def load_seed_mask(path: Path) -> np.ndarray:
    mat = loadmat(path)
    if "seedMask" in mat:
        mask = np.asarray(mat["seedMask"])
    elif "seed_mask" in mat:
        mask = np.asarray(mat["seed_mask"])
    else:
        raise ValueError(f"{path} has no seedMask variable")
    mask = np.squeeze(mask).astype(bool)
    if mask.ndim != 2:
        raise ValueError(f"Expected seed mask as [H,W], got {mask.shape}")
    return mask


def prompt_points_from_seed_mask(mask: np.ndarray, margin: int = 4) -> tuple[list[list[float]], list[int]]:
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        raise ValueError("Seed mask is empty")
    height, width = mask.shape
    cx0 = float(xs.mean())
    cy0 = float(ys.mean())
    center_idx = int(np.argmin((xs - cx0) ** 2 + (ys - cy0) ** 2))
    cx = float(xs[center_idx])
    cy = float(ys[center_idx])
    x0 = int(xs.min())
    x1 = int(xs.max())
    y0 = int(ys.min())
    y1 = int(ys.max())
    candidates = [
        (cx, max(0, y0 - margin)),
        (cx, min(height - 1, y1 + margin)),
        (max(0, x0 - margin), cy),
        (min(width - 1, x1 + margin), cy),
        (max(0, x0 - margin), max(0, y0 - margin)),
        (min(width - 1, x1 + margin), max(0, y0 - margin)),
        (max(0, x0 - margin), min(height - 1, y1 + margin)),
        (min(width - 1, x1 + margin), min(height - 1, y1 + margin)),
    ]
    points = [[cx, cy]]
    labels = [1]
    for nx, ny in candidates:
        ix = int(round(nx))
        iy = int(round(ny))
        if mask[iy, ix]:
            continue
        points.append([float(nx), float(ny)])
        labels.append(0)
    return points, labels


def load_provider_labels(
    path: Path | None,
    fallback_shape: tuple[int, int],
    num_frames: int,
) -> np.ndarray | None:
    if path is None or not path.exists():
        return None
    mat = loadmat(path)
    raw = mat.get("providerLabels", mat.get("provider_labels"))
    if raw is None:
        raise ValueError(f"{path} has no providerLabels variable")
    labels = np.squeeze(np.asarray(raw))
    if labels.ndim == 2:
        labels = labels[:, :, None]
    if labels.ndim != 3:
        raise ValueError(f"Expected provider labels as [H,W,T], got {labels.shape}")
    if labels.shape[2] != num_frames and labels.shape[0] == num_frames:
        labels = np.moveaxis(labels, 0, 2)
    if labels.shape[2] != num_frames:
        raise ValueError(
            f"Provider has {labels.shape[2]} frames but correction input has {num_frames}"
        )
    resized = np.zeros((fallback_shape[0], fallback_shape[1], num_frames), dtype=np.uint16)
    for frame_idx in range(num_frames):
        resized[:, :, frame_idx] = resize_labels_nearest(labels[:, :, frame_idx], fallback_shape)
    return resized


def mask_centroid(mask: np.ndarray) -> tuple[float, float]:
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return float("nan"), float("nan")
    return float(xs.mean()), float(ys.mean())


def provider_track_candidates(
    provider_labels: np.ndarray | None,
    seed_mask: np.ndarray,
    *,
    min_seed_iou: float = 0.02,
    min_iou: float = 0.01,
    dilation_radius: int = 3,
    max_centroid_distance: float = 0.0,
    max_gap: int = 2,
) -> tuple[np.ndarray | None, dict[str, Any]]:
    """Follow the seed through an instance-label provider, allowing label changes."""
    stats: dict[str, Any] = {
        "available": provider_labels is not None,
        "selected_labels": [],
        "frame_scores": [],
    }
    if provider_labels is None:
        stats["reason"] = "provider_unavailable"
        return None, stats

    from scipy.ndimage import binary_dilation  # noqa: WPS433

    height, width, num_frames = provider_labels.shape
    seed_labels = provider_labels[:, :, 0]
    best_seed_label = 0
    best_seed_iou = 0.0
    for label in [int(v) for v in np.unique(seed_labels) if v != 0]:
        iou = label_iou(seed_labels == label, seed_mask)
        if iou > best_seed_iou:
            best_seed_iou = iou
            best_seed_label = label
    stats["best_seed_label"] = int(best_seed_label)
    stats["best_seed_iou"] = float(best_seed_iou)
    if best_seed_label == 0 or best_seed_iou < min_seed_iou:
        stats["reason"] = "no_provider_object_overlaps_seed"
        return None, stats

    masks = np.zeros((height, width, num_frames), dtype=np.uint8)
    masks[:, :, 0] = seed_mask.astype(np.uint8)
    reference = seed_mask.astype(bool)
    previous_label = best_seed_label
    gap = 0
    selected_labels = [best_seed_label]
    frame_scores: list[dict[str, Any]] = [
        {"frame_index": 0, "label": best_seed_label, "seed_iou": float(best_seed_iou)}
    ]

    for frame_idx in range(1, num_frames):
        labels = provider_labels[:, :, frame_idx]
        ref_area = max(1, int(reference.sum()))
        auto_distance = max(4.0, 2.5 * np.sqrt(ref_area / np.pi))
        allowed_distance = float(max_centroid_distance) if max_centroid_distance > 0 else auto_distance
        ref_center = mask_centroid(reference)
        if dilation_radius > 0:
            dilated_reference = binary_dilation(reference, iterations=int(dilation_radius))
        else:
            dilated_reference = reference
        best: tuple[float, int, np.ndarray, dict[str, Any]] | None = None

        for label in [int(v) for v in np.unique(labels) if v != 0]:
            candidate = labels == label
            candidate_area = int(candidate.sum())
            if candidate_area == 0:
                continue
            area_ratio = candidate_area / ref_area
            if area_ratio < 0.30 or area_ratio > 3.0:
                continue
            raw_iou = label_iou(reference, candidate)
            dilated_iou = label_iou(dilated_reference, candidate)
            center = mask_centroid(candidate)
            distance = float(np.hypot(center[0] - ref_center[0], center[1] - ref_center[1]))
            if raw_iou < min_iou and dilated_iou <= 0 and distance > allowed_distance:
                continue
            area_similarity = min(area_ratio, 1.0 / max(area_ratio, 1e-9))
            distance_score = float(np.exp(-distance / max(allowed_distance, 1e-6)))
            score = 5.0 * raw_iou + 2.0 * dilated_iou + 1.5 * distance_score + area_similarity
            if label == previous_label:
                score += 0.15
            details = {
                "frame_index": frame_idx,
                "label": label,
                "score": float(score),
                "iou": float(raw_iou),
                "dilated_iou": float(dilated_iou),
                "centroid_distance": distance,
                "allowed_distance": allowed_distance,
                "area_ratio": float(area_ratio),
            }
            if best is None or score > best[0]:
                best = (score, label, candidate, details)

        if best is None:
            gap += 1
            selected_labels.append(0)
            frame_scores.append({"frame_index": frame_idx, "missing": True, "gap": gap})
            if gap > max_gap:
                break
            continue

        _, previous_label, reference, details = best
        gap = 0
        masks[:, :, frame_idx] = reference.astype(np.uint8)
        selected_labels.append(int(previous_label))
        frame_scores.append(details)

    stats["selected_labels"] = selected_labels
    stats["frame_scores"] = frame_scores
    stats["candidate_pixels_by_frame"] = masks.sum(axis=(0, 1)).astype(int).tolist()
    if int(masks[:, :, 1:].sum()) == 0:
        stats["reason"] = "provider_has_no_following_candidate"
        return None, stats
    return masks, stats


def mask_prompt_track_candidates(
    predictor,
    image_dir: Path,
    num_frames: int,
    seed_mask: np.ndarray,
    min_score: float,
    fallback_shape: tuple[int, int],
    cancel_path: Path | None,
    prompt_margin: int = 4,
    prompt_obj_id: int = 0,
) -> tuple[np.ndarray | None, dict[str, Any]]:
    """Experimental mask-only SAM31 propagation retained as the last fallback."""
    from sam31_ctc_benchmark.sam31_runner import mark_seed_frame_ready, output_to_label_mask
    import torch

    points, point_labels = prompt_points_from_seed_mask(seed_mask, margin=prompt_margin)
    response = predictor.handle_request(request={"type": "start_session", "resource_path": str(image_dir)})
    session_id = response["session_id"]
    try:
        predictor.handle_request(request={"type": "reset_session", "session_id": session_id})
        check_cancel(cancel_path, "before mask-only correction prompt")
        predictor.handle_request(
            request={
                "type": "add_prompt",
                "session_id": session_id,
                "frame_index": 0,
                "points": points,
                "point_labels": point_labels,
                "obj_id": int(prompt_obj_id),
                "rel_coordinates": False,
                "output_prob_thresh": min_score,
            }
        )
        inference_state = predictor._all_inference_states[session_id]["state"]
        mask_tensor = torch.from_numpy(seed_mask.astype(np.float32)[None]).to(predictor.model.device)
        obj_ids = [int(prompt_obj_id)]
        tracker_states = predictor.model._get_sam2_inference_states_by_obj_ids(inference_state, obj_ids)
        if len(tracker_states) == 1:
            predictor.model.tracker.add_new_masks(
                tracker_states[0], frame_idx=0, obj_ids=obj_ids, masks=mask_tensor
            )
        elif len(tracker_states) == len(obj_ids):
            for tracker_state, obj_id, mask in zip(tracker_states, obj_ids, mask_tensor):
                predictor.model.tracker.add_new_masks(
                    tracker_state, frame_idx=0, obj_ids=[obj_id], masks=mask[None]
                )
        else:
            raise RuntimeError(
                f"Expected one tracker state or one per object, got {len(tracker_states)}"
            )
        predictor.model.add_action_history(inference_state, "refine", frame_idx=0, obj_ids=obj_ids)
        mark_seed_frame_ready(predictor, session_id, 0)
        outputs = stream_propagate_in_video(
            predictor,
            session_id,
            total_frames=num_frames,
            min_score=min_score,
            cancel_path=cancel_path,
            prefix="[SAM31 mask fallback PY]",
        )
    finally:
        predictor.handle_request(request={"type": "close_session", "session_id": session_id})

    height, width = fallback_shape
    masks = np.zeros((height, width, num_frames), dtype=np.uint8)
    stats_by_frame: list[dict[str, Any]] = []
    for frame_idx in range(num_frames):
        output = outputs.get(frame_idx)
        if output is None:
            stats_by_frame.append({"frame_index": frame_idx, "missing_output": True})
            continue
        labels = resize_labels_nearest(output_to_label_mask(output, min_score=min_score), fallback_shape)
        target_label = int(prompt_obj_id) + 1
        candidate = labels == target_label
        if not np.any(candidate):
            candidate = labels > 0
        masks[:, :, frame_idx] = candidate.astype(np.uint8)
        stats_by_frame.append(
            {
                "frame_index": frame_idx,
                "num_candidate_pixels": int(candidate.sum()),
                "output_debug": output_debug_summary(output),
            }
        )
    stats = {
        "stats_by_frame": stats_by_frame,
        "candidate_pixels_by_frame": masks.sum(axis=(0, 1)).astype(int).tolist(),
    }
    if int(masks[:, :, 1:].sum()) == 0:
        stats["reason"] = "mask_prompt_has_no_following_candidate"
        return None, stats
    return masks, stats


def run_track_correction(cfg: dict[str, Any], output_dir: Path, cancel_path: Path | None) -> None:
    input_mat_path = as_local_path(cfg["input_mat_path"])
    seed_mask_path = as_local_path(cfg["seed_mask_mat_path"])
    if input_mat_path is None or seed_mask_path is None:
        raise SystemExit("Missing input_mat_path or seed_mask_mat_path")

    raw, frames = load_raw_stack(input_mat_path)
    seed_mask = load_seed_mask(seed_mask_path)
    if seed_mask.shape != (raw.shape[0], raw.shape[1]):
        seed_mask = resize_labels_nearest(seed_mask.astype(np.uint16), (raw.shape[0], raw.shape[1])) > 0

    image_dir = output_dir / "sam31_track_correction_images"
    write_image_sequence(raw, image_dir, cancel_path=cancel_path)
    check_cancel(cancel_path, "after correction image export")
    height, width = raw.shape[0], raw.shape[1]
    provider_path = as_local_path(cfg.get("candidate_provider_mat_path"))
    provider_labels = load_provider_labels(
        provider_path,
        fallback_shape=(height, width),
        num_frames=raw.shape[3],
    )

    video_kwargs = {
        "score_threshold_detection": scalar_number(cfg.get("video_score_threshold"), 0.40, "video_score_threshold", minimum=0.0),
        "new_det_thresh": scalar_number(cfg.get("video_new_det_threshold"), 0.40, "video_new_det_threshold", minimum=0.0),
        "det_nms_thresh": scalar_number(cfg.get("video_det_nms_threshold"), 0.10, "video_det_nms_threshold", minimum=0.0),
        "assoc_iou_thresh": scalar_number(cfg.get("video_assoc_iou_threshold"), 0.50, "video_assoc_iou_threshold", minimum=0.0),
        "hotstart_unmatch_thresh": scalar_number(cfg.get("hotstart_unmatch_thresh"), 3, "hotstart_unmatch_thresh", integer=True, minimum=1.0),
        "max_num_objects": scalar_number(cfg.get("max_num_objects"), 120, "max_num_objects", integer=True, minimum=1.0),
    }
    image_size = scalar_number(cfg.get("image_size"), 560, "image_size", integer=True, minimum=1.0)
    min_score = scalar_number(cfg.get("min_score"), 0.0, "min_score", minimum=0.0)
    search_roots = [
        path
        for path in (as_local_path(value) for value in cfg.get("checkpoint_search_roots", []))
        if path is not None
    ]

    # Hybrid order: native text detection first, then the existing mask
    # provider, and only then the experimental mask injection path.
    attempts: dict[str, Any] = {}
    predictor = None
    text_masks = None
    if bool_value(cfg.get("fallback_text_track"), True):
        try:
            detector_checkpoint_path = resolve_checkpoint(
                cfg.get("detector_checkpoint_path"),
                output_dir=output_dir,
                image_size=image_size,
                kind="detector",
                search_roots=search_roots,
            )
            tracker_checkpoint_path = resolve_checkpoint(
                cfg.get("tracker_checkpoint_path"),
                output_dir=output_dir,
                image_size=image_size,
                kind="tracker",
                search_roots=search_roots,
            )
            predictor = get_predictor(
                detector_checkpoint_path=detector_checkpoint_path,
                tracker_checkpoint_path=tracker_checkpoint_path,
                image_size=image_size,
                video_kwargs=video_kwargs,
            )
            text_masks, attempts["text"] = text_track_candidates(
                predictor=predictor,
                image_dir=image_dir,
                num_frames=raw.shape[3],
                seed_mask=seed_mask,
                min_score=min_score,
                fallback_shape=(height, width),
                cancel_path=cancel_path,
                prompt=str(cfg.get("prompt", "cell")),
                min_seed_iou=scalar_number(
                    cfg.get("fallback_min_seed_iou"), 0.02, "fallback_min_seed_iou", minimum=0.0
                ),
            )
        except Exception as exc:  # provider tracking must remain usable without a model
            attempts["text"] = {"reason": "sam31_text_failed", "error": str(exc)}
            print(f"[SAM31 correction PY] text strategy failed: {exc}", flush=True)

    provider_masks = None
    if bool_value(cfg.get("fallback_provider_track"), True):
        provider_masks, attempts["provider"] = provider_track_candidates(
            provider_labels,
            seed_mask,
            min_seed_iou=scalar_number(
                cfg.get("provider_min_seed_iou"), 0.02, "provider_min_seed_iou", minimum=0.0
            ),
            min_iou=scalar_number(cfg.get("provider_min_iou"), 0.01, "provider_min_iou", minimum=0.0),
            dilation_radius=scalar_number(
                cfg.get("provider_dilation_radius"), 3, "provider_dilation_radius", integer=True, minimum=0.0
            ),
            max_centroid_distance=scalar_number(
                cfg.get("provider_max_centroid_distance"),
                0.0,
                "provider_max_centroid_distance",
                minimum=0.0,
            ),
            max_gap=scalar_number(cfg.get("provider_max_gap"), 2, "provider_max_gap", integer=True, minimum=0.0),
        )

    candidate_masks = None
    strategy_method = "none"
    if text_masks is not None and int(text_masks[:, :, 1:].sum()) > 0:
        candidate_masks = text_masks.copy()
        strategy_method = "text"
        if provider_masks is not None:
            filled = 0
            for frame_idx in range(1, raw.shape[3]):
                if not np.any(candidate_masks[:, :, frame_idx]) and np.any(provider_masks[:, :, frame_idx]):
                    candidate_masks[:, :, frame_idx] = provider_masks[:, :, frame_idx]
                    filled += 1
            if filled:
                strategy_method = "text+provider"
                attempts["provider"]["filled_text_gaps"] = int(filled)
    elif provider_masks is not None and int(provider_masks[:, :, 1:].sum()) > 0:
        candidate_masks = provider_masks
        strategy_method = "provider"

    if candidate_masks is not None:
        candidate_masks[:, :, 0] = seed_mask.astype(np.uint8)
        output_dir.mkdir(parents=True, exist_ok=True)
        savemat(
            output_dir / "track_correction.mat",
            {
                "candidate_masks": candidate_masks,
                "frames_list": frames.reshape(1, -1),
                "strategy_method": strategy_method,
            },
            do_compression=True,
        )
        (output_dir / "track_correction_stats.json").write_text(
            json.dumps(
                {
                    "frames": int(raw.shape[3]),
                    "strategy_method": strategy_method,
                    "provider_name": str(cfg.get("candidate_provider_name", "")),
                    "attempts": attempts,
                },
                indent=2,
                default=str,
            ),
            encoding="utf-8",
        )
        return

    if predictor is None:
        raise RuntimeError(
            "SAM31 text detection failed and no usable mask provider candidate was found; "
            f"attempts={attempts}"
        )
    if not bool_value(cfg.get("fallback_mask_prompt"), True):
        raise RuntimeError(f"No text/provider candidate was found; attempts={attempts}")

    prompt_margin = scalar_number(cfg.get("prompt_margin"), 4, "prompt_margin", integer=True, minimum=0.0)
    prompt_obj_id = scalar_number(cfg.get("prompt_obj_id"), 0, "prompt_obj_id", integer=True, minimum=0.0)
    candidate_masks, mask_stats = mask_prompt_track_candidates(
        predictor=predictor,
        image_dir=image_dir,
        num_frames=raw.shape[3],
        seed_mask=seed_mask,
        min_score=min_score,
        fallback_shape=(height, width),
        cancel_path=cancel_path,
        prompt_margin=int(prompt_margin),
        prompt_obj_id=int(prompt_obj_id),
    )
    if candidate_masks is None:
        candidate_masks = np.zeros((height, width, raw.shape[3]), dtype=np.uint8)

    candidate_masks[:, :, 0] = seed_mask.astype(np.uint8)
    future_pixels = int(candidate_masks[:, :, 1:].sum()) if raw.shape[3] > 1 else 0
    strategy_method = "mask_prompt" if future_pixels > 0 else "none"
    attempts["mask_prompt"] = {
        "candidate_pixels_by_frame": candidate_masks.sum(axis=(0, 1)).astype(int).tolist(),
        "details": mask_stats,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    savemat(
        output_dir / "track_correction.mat",
        {
            "candidate_masks": candidate_masks,
            "frames_list": frames.reshape(1, -1),
            "strategy_method": strategy_method,
        },
        do_compression=True,
    )
    (output_dir / "track_correction_stats.json").write_text(
        json.dumps(
            {
                "frames": int(raw.shape[3]),
                "strategy_method": strategy_method,
                "provider_name": str(cfg.get("candidate_provider_name", "")),
                "attempts": attempts,
            },
            indent=2,
            default=str,
        ),
        encoding="utf-8",
    )


def text_track_candidates(
    predictor,
    image_dir: Path,
    num_frames: int,
    seed_mask: np.ndarray,
    min_score: float,
    fallback_shape: tuple[int, int],
    cancel_path: Path | None,
    prompt: str = "cell",
    min_seed_iou: float = 0.02,
) -> tuple[np.ndarray | None, dict[str, Any]]:
    labels_by_frame, text_stats = run_sam31_text_movie(
        predictor=predictor,
        image_dir=image_dir,
        num_frames=num_frames,
        prompt=prompt,
        min_score=min_score,
        fallback_shape=fallback_shape,
        chunk_size=0,
        chunk_overlap=0,
        cancel_path=cancel_path,
    )
    seed_labels = resize_labels_nearest(labels_by_frame[0], seed_mask.shape)
    best_label = 0
    best_iou = 0.0
    for label in [int(v) for v in np.unique(seed_labels) if v != 0]:
        mask = seed_labels == label
        iou = label_iou(mask, seed_mask)
        if iou > best_iou:
            best_iou = iou
            best_label = label
    stats = {
        "best_seed_label": int(best_label),
        "best_seed_iou": float(best_iou),
        "text_stats_by_frame": text_stats,
    }
    if best_label == 0 or best_iou < min_seed_iou:
        stats["reason"] = "no_text_track_overlaps_seed"
        return None, stats

    masks = np.zeros((fallback_shape[0], fallback_shape[1], num_frames), dtype=np.uint8)
    for frame_idx, labels in enumerate(labels_by_frame):
        labels = resize_labels_nearest(labels, fallback_shape)
        masks[:, :, frame_idx] = (labels == best_label).astype(np.uint8)
    stats["candidate_pixels_by_frame"] = masks.sum(axis=(0, 1)).astype(int).tolist()
    return masks, stats


def output_debug_summary(output: dict[str, Any]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for key in ("out_obj_ids", "out_probs", "removed_obj_ids", "suppressed_obj_ids", "unconfirmed_obj_ids"):
        if key in output:
            summary[key] = np.asarray(output[key]).reshape(-1).tolist()
    masks = output.get("out_binary_masks")
    if masks is not None:
        if hasattr(masks, "detach"):
            masks = masks.detach().cpu().numpy()
        masks_arr = np.asarray(masks)
        if masks_arr.ndim == 4 and masks_arr.shape[1] == 1:
            masks_arr = masks_arr[:, 0]
        if masks_arr.ndim == 3:
            summary["raw_mask_pixels"] = masks_arr.astype(bool).sum(axis=(1, 2)).astype(int).tolist()
            summary["raw_mask_shape"] = list(masks_arr.shape)
        else:
            summary["raw_mask_shape"] = list(masks_arr.shape)
    return summary


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

    if str(cfg.get("task", "classify")) == "track_correction":
        run_track_correction(cfg, output_dir=output_dir, cancel_path=cancel_path)
        return

    raw, frames = load_raw_stack(input_mat_path)
    image_dir = output_dir / "sam31_images"
    write_image_sequence(raw, image_dir, cancel_path=cancel_path)
    check_cancel(cancel_path, "after image export")

    infer_instance_segmentation = bool_value(cfg.get("infer_instance_segmentation"), True)
    infer_cell_tracking = bool_value(cfg.get("infer_cell_tracking"), True)
    if infer_cell_tracking and not infer_instance_segmentation:
        print("[SAM31 classify] cell tracking requires instance segmentation; enabling instance segmentation", flush=True)
        infer_instance_segmentation = True
    if not infer_instance_segmentation:
        infer_cell_tracking = False

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
        "hotstart_unmatch_thresh": scalar_number(cfg.get("hotstart_unmatch_thresh"), 3, "hotstart_unmatch_thresh", integer=True, minimum=1.0),
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
    applied_builder_kwargs = dict(getattr(predictor, "sam31_builder_kwargs", {}))
    applied_video_kwargs = dict(getattr(predictor, "sam31_applied_video_kwargs", {}))
    ignored_video_kwargs = dict(getattr(predictor, "sam31_ignored_video_kwargs", {}))
    print(
        "[SAM31 classify PY] requested tracker params: "
        f"max_num_objects={video_kwargs['max_num_objects']} "
        f"hotstart_unmatch_thresh={video_kwargs['hotstart_unmatch_thresh']}; "
        f"applied hotstart_unmatch_thresh="
        f"{applied_video_kwargs.get('hotstart_unmatch_thresh', 'model-default')}",
        flush=True,
    )
    chunk_size = scalar_number(cfg.get("chunk_size"), 0, "chunk_size", integer=True, minimum=0.0)
    chunk_overlap = scalar_number(cfg.get("chunk_overlap"), 0, "chunk_overlap", integer=True, minimum=0.0)
    labels_by_frame, stats_by_frame = run_sam31_text_movie(
        predictor=predictor,
        image_dir=image_dir,
        num_frames=raw.shape[3],
        prompt=str(cfg.get("prompt", "cell")),
        min_score=scalar_number(cfg.get("min_score"), 0.0, "min_score", minimum=0.0),
        fallback_shape=(raw.shape[0], raw.shape[1]),
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        cancel_path=cancel_path,
    )
    if not infer_cell_tracking:
        labels_by_frame = frame_local_instance_labels(labels_by_frame)
        for row in stats_by_frame:
            row["frame_local_instances"] = True

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
        json.dumps(
            {
                "frames": len(labels_by_frame),
                "requested_video_kwargs": video_kwargs,
                "applied_builder_kwargs": applied_builder_kwargs,
                "applied_video_kwargs": applied_video_kwargs,
                "ignored_video_kwargs": ignored_video_kwargs,
                "chunk_size": chunk_size,
                "chunk_overlap": chunk_overlap,
                "stats_by_frame": stats_by_frame,
            },
            indent=2,
            default=str,
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="DetecDiv bridge for SAM31 ROI inference.")
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    run(args.config)


if __name__ == "__main__":
    main()
