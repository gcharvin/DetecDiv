from __future__ import annotations

import argparse
import json
import platform
import subprocess
from pathlib import Path


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


def run(cmd: list[str | Path], cwd: Path, log_path: Path) -> None:
    printable = " ".join(str(part) for part in cmd)
    print(printable, flush=True)
    with log_path.open("a", encoding="utf-8") as log:
        log.write(f"\n$ {printable}\n")
        proc = subprocess.run(
            [str(part) for part in cmd],
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        log.write(proc.stdout)
    if proc.returncode != 0:
        raise SystemExit(proc.returncode)


def split_list(value) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item)]
    return [part for part in str(value).split() if part]


def main() -> None:
    parser = argparse.ArgumentParser(description="DetecDiv bridge for generic SAM31 training.")
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()

    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    repo_root = as_local_path(cfg["repo_root"])
    sam3_repo = as_local_path(cfg["sam3_repo"])
    artifacts_root = as_local_path(cfg["artifacts_root"])
    dataset_root = as_local_path(cfg["dataset_root"])
    python = cfg.get("python") or "python"
    resolution = int(cfg.get("resolution", 280))
    num_gpus = int(cfg.get("num_gpus", 1))
    modules = split_list(cfg.get("modules")) or ["instance"]
    splits = split_list(cfg.get("splits")) or ["train", "val"]
    log_path = args.config.with_name("train_sam31_runner.log")

    if repo_root is None or sam3_repo is None or artifacts_root is None or dataset_root is None:
        raise SystemExit("Missing repo_root, sam3_repo, artifacts_root, or dataset_root")

    common = [
        python,
        repo_root / "scripts" / "sam31_moma.py",
        "--repo-root",
        repo_root,
        "--sam3-repo",
        sam3_repo,
        "--artifacts-root",
        artifacts_root,
        "--python",
        python,
        "--resolution",
        resolution,
        "--num-gpus",
        num_gpus,
    ]
    if not bool(cfg.get("dry_run", False)):
        common.append("--run")

    if bool(cfg.get("prepare_before_train", True)):
        run(
            [
                *common,
                "prepare",
                "--dataset-root",
                dataset_root,
                "--splits",
                *splits,
                "--image-dataset-name",
                cfg.get("image_dataset_name", "moma_sam31_image_coco"),
                "--video-dataset-name",
                cfg.get("video_dataset_name", "moma_sam31_video"),
                "--tracklet-dataset-name",
                cfg.get("tracklet_dataset_name", "moma_sam31_tracklet_clips_len8_ref"),
                "--clip-length",
                int(cfg.get("clip_length", 8)),
                "--clip-stride",
                int(cfg.get("clip_stride", 4)),
                "--max-tracks-per-clip",
                int(cfg.get("max_tracks_per_clip", 8)),
                "--min-visible-frames",
                int(cfg.get("min_visible_frames", 4)),
            ],
            cwd=repo_root,
            log_path=log_path,
        )

    if bool(cfg.get("prepare_only", False)):
        print("prepare_only=true: stopping before SAM31 training.", flush=True)
        return

    run(
        [
            *common,
            "train",
            "--modules",
            *modules,
            "--image-dataset-name",
            cfg.get("image_dataset_name", "moma_sam31_image_coco"),
            "--tracklet-dataset-name",
            cfg.get("tracklet_dataset_name", "moma_sam31_tracklet_clips_len8_ref"),
            "--epochs",
            int(cfg.get("epochs", 20)),
            "--save-freq",
            int(cfg.get("save_freq", 100000)),
            "--clip-length",
            int(cfg.get("clip_length", 8)),
            "--stage-stride-max",
            int(cfg.get("stage_stride_max", 4)),
            "--max-tracks-per-datapoint",
            int(cfg.get("max_tracks_per_datapoint", 8)),
        ],
        cwd=repo_root,
        log_path=log_path,
    )


if __name__ == "__main__":
    main()
