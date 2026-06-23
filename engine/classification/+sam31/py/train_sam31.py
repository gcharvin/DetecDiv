from __future__ import annotations

import argparse
import json
import os
import platform
import re
import signal
import subprocess
import sys
import time
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


def is_cancel_requested(cancel_path: Path | None) -> bool:
    return cancel_path is not None and cancel_path.exists()


def terminate_process_tree(proc: subprocess.Popen) -> None:
    try:
        if platform.system() == "Windows":
            proc.terminate()
        else:
            os.killpg(proc.pid, signal.SIGTERM)
    except Exception:
        try:
            proc.terminate()
        except Exception:
            pass
    try:
        proc.wait(timeout=10)
        return
    except Exception:
        pass
    try:
        if platform.system() == "Windows":
            proc.kill()
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


TRAIN_RE = re.compile(r"Train Epoch:\s*\[(?P<epoch>\d+)\]\[\s*(?P<iter>\d+)\s*/\s*(?P<total>\d+)\]")
LOSS_RE = re.compile(
    r"Losses/train_(?:all|moma_video)_loss:\s*(?P<current>[0-9.eE+-]+)\s*\((?P<average>[0-9.eE+-]+)\)"
)
ETA_RE = re.compile(r"Estimated time remaining:\s*(?P<eta>.+)$")


def write_progress(progress_path: Path | None, payload: dict) -> None:
    if progress_path is None:
        return
    try:
        progress_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = progress_path.with_suffix(progress_path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        tmp.replace(progress_path)
    except Exception:
        pass


def update_progress_from_line(
    line: str,
    *,
    progress_path: Path | None,
    state: dict,
) -> None:
    changed = False
    m = TRAIN_RE.search(line)
    if m:
        epoch = int(m.group("epoch"))
        iteration = int(m.group("iter"))
        total = int(m.group("total"))
        state.update(
            {
                "status": "training",
                "epoch": epoch,
                "iter": iteration,
                "iter_total": total,
                "where": epoch + (iteration / total if total else 0),
                "last_train_line": line.rstrip(),
                "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        changed = True
    m = LOSS_RE.search(line)
    if m:
        state["loss_current"] = float(m.group("current"))
        state["loss_average"] = float(m.group("average"))
        changed = True
    m = ETA_RE.search(line)
    if m:
        state["eta"] = m.group("eta").strip()
        changed = True
    if changed:
        write_progress(progress_path, state)


def run(
    cmd: list[str | Path],
    cwd: Path,
    log_path: Path,
    cancel_path: Path | None = None,
    progress_path: Path | None = None,
    progress_state: dict | None = None,
) -> str:
    printable = " ".join(str(part) for part in cmd)
    print(printable, flush=True)
    if progress_state is not None:
        progress_state.update(
            {
                "status": progress_state.get("status", "running"),
                "command": printable,
                "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        write_progress(progress_path, progress_state)
    with log_path.open("a", encoding="utf-8") as log:
        log.write(f"\n$ {printable}\n")
        log.flush()
        proc = subprocess.Popen(
            [str(part) for part in cmd],
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=1,
            start_new_session=(platform.system() != "Windows"),
        )
        output: list[str] = []
        assert proc.stdout is not None
        while proc.poll() is None:
            line = proc.stdout.readline()
            if line:
                output.append(line)
                print(line, end="", flush=True)
                log.write(line)
                log.flush()
                if progress_state is not None:
                    update_progress_from_line(line, progress_path=progress_path, state=progress_state)
            else:
                if is_cancel_requested(cancel_path):
                    terminate_process_tree(proc)
                    remaining = proc.stdout.read() or ""
                    if remaining:
                        output.append(remaining)
                        print(remaining, end="", flush=True)
                        log.write(remaining)
                    log.write("\n[CANCELLED] DetecDiv cancel token detected.\n")
                    log.flush()
                    if progress_state is not None:
                        progress_state.update({"status": "cancelled", "updated_at": time.strftime("%Y-%m-%d %H:%M:%S")})
                        write_progress(progress_path, progress_state)
                    raise SystemExit(130)
                time.sleep(0.2)
        remaining = proc.stdout.read() or ""
        if remaining:
            output.append(remaining)
            print(remaining, end="", flush=True)
            log.write(remaining)
            if progress_state is not None:
                for line in remaining.splitlines():
                    update_progress_from_line(line, progress_path=progress_path, state=progress_state)
        log.flush()
    if proc.returncode != 0:
        if progress_state is not None:
            progress_state.update(
                {
                    "status": "failed",
                    "returncode": proc.returncode,
                    "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                }
            )
            write_progress(progress_path, progress_state)
        raise SystemExit(proc.returncode)
    if progress_state is not None:
        progress_state.update(
            {
                "status": "done",
                "returncode": proc.returncode,
                "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
        )
        write_progress(progress_path, progress_state)
    return "".join(output)


def split_list(value) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item)]
    return [part for part in str(value).split() if part]


def normalize_run_policy(value) -> str:
    text = str(value or "resume").strip().lower()
    if text in {"restart", "fresh", "replace", "reset"}:
        return "restart"
    return "resume"


def append_log(log_path: Path, message: str) -> None:
    with log_path.open("a", encoding="utf-8") as log:
        log.write(message.rstrip() + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="DetecDiv bridge for generic SAM31 training.")
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()

    cfg = json.loads(args.config.read_text(encoding="utf-8"))
    repo_root = as_local_path(cfg["repo_root"])
    sam3_repo = as_local_path(cfg["sam3_repo"])
    artifacts_root = as_local_path(cfg["artifacts_root"])
    dataset_root = as_local_path(cfg["dataset_root"])
    cancel_path = as_local_path(cfg.get("cancel_path"))
    python = cfg.get("python") or sys.executable
    resolution = int(cfg.get("resolution", 280))
    num_gpus = int(cfg.get("num_gpus", 1))
    modules = split_list(cfg.get("modules")) or ["instance"]
    splits = split_list(cfg.get("splits")) or ["train", "val"]
    if "run_policy" not in cfg or not str(cfg.get("run_policy") or "").strip():
        raise SystemExit(
            "SAM31 training config is missing run_policy. "
            "This usually means the Hub worker loaded a stale DetecDiv MATLAB path."
        )
    run_policy = normalize_run_policy(cfg.get("run_policy"))
    log_path = args.config.with_name("train_sam31_runner.log")
    run_path = as_local_path(cfg.get("run_path"))
    progress_path = (run_path / "progress.json") if run_path is not None else args.config.with_name("progress.json")
    progress_state = {
        "status": "starting",
        "stage": "sam31",
        "run_id": cfg.get("run_id", ""),
        "run_path": cfg.get("run_path", ""),
        "log_path": str(log_path),
        "modules": modules,
        "max_epochs": int(cfg.get("epochs", 20)),
        "resolution": resolution,
        "run_policy": run_policy,
        "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    write_progress(progress_path, progress_state)
    log_path.write_text(
        (
            "[SAM31 TRAIN RUNNER]\n"
            f"config: {args.config}\n"
            f"run_policy: {run_policy}\n"
            f"run_id: {cfg.get('run_id', '')}\n"
            f"run_path: {cfg.get('run_path', '')}\n"
        ),
        encoding="utf-8",
    )

    if repo_root is None or sam3_repo is None or artifacts_root is None or dataset_root is None:
        raise SystemExit("Missing repo_root, sam3_repo, artifacts_root, or dataset_root")
    if is_cancel_requested(cancel_path):
        raise SystemExit("DetecDiv run cancelled before SAM31 training.")

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
            cancel_path=cancel_path,
            progress_path=progress_path,
            progress_state={**progress_state, "status": "preparing", "stage": "prepare"},
        )
        if is_cancel_requested(cancel_path):
            raise SystemExit("DetecDiv run cancelled after SAM31 prepare.")

    if bool(cfg.get("prepare_only", False)):
        print("prepare_only=true: stopping before SAM31 training.", flush=True)
        return

    train_cmd = [
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
        "--resume-policy",
        run_policy,
    ]
    train_output = run(
        train_cmd,
        cwd=repo_root,
        log_path=log_path,
        cancel_path=cancel_path,
        progress_path=progress_path,
        progress_state={**progress_state, "status": "training", "stage": "train"},
    )
    if not bool(cfg.get("dry_run", False)) and "Train Epoch:" not in train_output:
        message = (
            "[SAM31 WARNING] The SAM3.1 training command completed without any "
            "'Train Epoch:' log line. In resume mode this usually means that an "
            "existing checkpoint has already reached the requested --epochs value. "
            "Select 'Restart from scratch' in pipeline2, delete the module artifact "
            "checkpoints, or increase epochs if you want additional training."
        )
        print(message, flush=True)
        append_log(log_path, message)
        if run_policy == "restart":
            raise SystemExit(
                "SAM31 restart run produced no training epochs; inspect train_sam31_runner.log."
            )


if __name__ == "__main__":
    main()
