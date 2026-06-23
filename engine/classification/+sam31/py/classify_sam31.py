from __future__ import annotations

import argparse
import json
import platform
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.io import loadmat, savemat


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


def run_sam31_text_movie(predictor, image_dir: Path, num_frames: int, prompt: str, min_score: float, fallback_shape: tuple[int, int], cancel_path: Path | None = None):
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


def main() -> None:
    parser = argparse.ArgumentParser(description="DetecDiv bridge for SAM31 ROI inference.")
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()

    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    repo_root = as_local_path(cfg["repo_root"])
    sam3_repo = as_local_path(cfg["sam3_repo"])
    input_mat_path = as_local_path(cfg["input_mat_path"])
    output_dir = as_local_path(cfg["output_dir"])
    cancel_path = as_local_path(cfg.get("cancel_path"))
    if repo_root is None or sam3_repo is None or input_mat_path is None or output_dir is None:
        raise SystemExit("Missing repo_root, sam3_repo, input_mat_path, or output_dir")
    check_cancel(cancel_path, "startup")

    sys.path.insert(0, str(repo_root))
    sys.path.insert(0, str(repo_root / "scripts"))
    sys.path.insert(0, str(sam3_repo))

    from sam31_ctc_benchmark.sam31_runner import build_predictor  # noqa: WPS433

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
        "score_threshold_detection": cfg.get("video_score_threshold"),
        "new_det_thresh": cfg.get("video_new_det_threshold"),
        "det_nms_thresh": cfg.get("video_det_nms_threshold"),
        "assoc_iou_thresh": cfg.get("video_assoc_iou_threshold"),
        "max_num_objects": cfg.get("max_num_objects"),
    }
    video_kwargs = {k: v for k, v in video_kwargs.items() if v is not None}
    predictor = build_predictor(
        detector_checkpoint_path=optional_path(cfg.get("detector_checkpoint_path")),
        tracker_checkpoint_path=optional_path(cfg.get("tracker_checkpoint_path")),
        image_size=int(cfg.get("image_size", 280)),
        video_kwargs=video_kwargs,
    )
    if int(cfg.get("chunk_size", 0)) > 0:
        raise ValueError("DetecDiv SAM31 classify runner currently supports full-session inference only; set chunkSize=0.")
    labels_by_frame, stats_by_frame = run_sam31_text_movie(
        predictor=predictor,
        image_dir=image_dir,
        num_frames=raw.shape[3],
        prompt=str(cfg.get("prompt", "cell")),
        min_score=float(cfg.get("min_score", 0.0)),
        fallback_shape=(raw.shape[0], raw.shape[1]),
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


if __name__ == "__main__":
    main()
