"""Generic DetecDiv runtime for the project47 HGB-16 bud/mother linker.

The runtime reads only tracked label masks. It emits an auditable JSON graph;
MATLAB owns the canonical ``cellModel`` update and persistence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

import h5py
import joblib
import numpy as np
import pandas as pd
from scipy import ndimage as ndi
from scipy.spatial import cKDTree


TOOL_VERSION = "1.0.0"
FEATURES = [
    "dist_0",
    "dist_std",
    "poly_fit_budcm_budpt",
    "poly_fit_expansion_vector",
    "position_bud_std",
    "position_bud_max",
    "position_bud_min",
    "position_bud_last",
    "position_bud_first",
    "orientation_bud_std",
    "orientation_bud_max",
    "orientation_bud_min",
    "orientation_bud_last",
    "orientation_bud_first",
    "orientation_bud_last_minus_first",
    "plyfit_orientation_bud",
]


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def scalar_attribute(dataset: h5py.Dataset, name: str) -> int | None:
    value = dataset.attrs.get(name)
    if value is None:
        return None
    return int(np.asarray(value).reshape(-1)[0])


def load_tracks(path: Path, dataset_name: str) -> np.ndarray:
    """Return a T,Y,X uint32 stack from DetecDiv or native project HDF5."""
    with h5py.File(path, "r") as handle:
        if dataset_name not in handle:
            raise KeyError(f"Dataset {dataset_name!r} is missing from {path}")
        dataset = handle[dataset_name]
        raw = np.asarray(dataset)
        height = scalar_attribute(dataset, "height")
        width = scalar_attribute(dataset, "width")
        frames = scalar_attribute(dataset, "frames")

    if raw.ndim == 4:
        # Native DetecDiv/project47 convention used by existing Python tools.
        if raw.shape[1] == 1:
            raw = raw[:, 0]
        elif raw.shape[-1] == 1:
            raw = raw[..., 0]
        else:
            raise ValueError(f"Expected a singleton channel dimension, got {raw.shape}")
    elif raw.ndim != 3:
        raise ValueError(f"Expected a 3-D or 4-D track stack, got {raw.shape}")

    if height is not None and width is not None and frames is not None:
        target = (frames, height, width)
        if raw.shape == target:
            tracks = raw
        elif raw.shape == (height, width, frames):
            tracks = np.transpose(raw, (2, 0, 1))
        elif raw.shape == (frames, width, height):
            tracks = np.transpose(raw, (0, 2, 1))
        elif raw.shape == (width, height, frames):
            tracks = np.transpose(raw, (2, 1, 0))
        else:
            raise ValueError(
                f"Cannot map stored shape {raw.shape} to logical YXT "
                f"({height}, {width}, {frames})"
            )
    else:
        # External native input is expected to be T,Y,X.
        tracks = raw

    if not np.issubdtype(tracks.dtype, np.integer):
        if not np.all(np.isfinite(tracks)) or not np.all(tracks == np.floor(tracks)):
            raise ValueError("Track masks must contain finite integer labels")
    tracks = np.asarray(tracks, dtype=np.uint32)
    return tracks


def label_stats(tracks: np.ndarray) -> dict[int, dict[str, Any]]:
    stats: dict[int, dict[str, Any]] = {}
    for frame, plane in enumerate(tracks):
        labels, counts = np.unique(plane, return_counts=True)
        for label, count in zip(labels, counts, strict=True):
            key = int(label)
            if key == 0:
                continue
            if key not in stats:
                stats[key] = {
                    "start": frame,
                    "end": frame,
                    "frames": 1,
                    "birth_area": int(count),
                }
            else:
                stats[key]["end"] = frame
                stats[key]["frames"] += 1
    return stats


def boundary_points(mask: np.ndarray) -> np.ndarray:
    boundary = mask & ~ndi.binary_erosion(mask)
    points = np.argwhere(boundary)
    return points if len(points) else np.argwhere(mask)


def pair_geometry(child_mask: np.ndarray, parent_mask: np.ndarray) -> tuple[float, int]:
    child_points = boundary_points(child_mask)
    parent_points = boundary_points(parent_mask)
    if not len(child_points) or not len(parent_points):
        return float("inf"), 0
    contour_distance = float(cKDTree(parent_points).query(child_points, k=1)[0].min())
    contact = int(np.count_nonzero(child_mask & ndi.binary_dilation(parent_mask)))
    return contour_distance, contact


def tracking_loads(tracks: np.ndarray) -> dict[int, int]:
    output: dict[int, int] = {}
    previous: set[int] = set()
    for frame, plane in enumerate(tracks):
        current = {int(value) for value in np.unique(plane) if int(value) > 0}
        output[frame] = len(current - previous)
        previous = current
    return output


def build_events(tracks: np.ndarray, args: argparse.Namespace) -> list[dict[str, Any]]:
    stats = label_stats(tracks)
    events: list[dict[str, Any]] = []
    eligible = [
        (child, state)
        for child, state in stats.items()
        if state["start"] > 0
        and state["frames"] >= args.min_lifetime
        and state["birth_area"] <= args.max_birth_area
    ]
    for child, state in sorted(eligible, key=lambda item: (item[1]["start"], item[0])):
        start = int(state["start"])
        current = tracks[start]
        previous = tracks[start - 1]
        child_mask = current == child
        yy, xx = np.where(child_mask)
        if not len(yy):
            continue
        cy, cx = float(yy.mean()), float(xx.mean())
        labels, counts = np.unique(current, return_counts=True)
        area_by_id = {
            int(label): int(count)
            for label, count in zip(labels, counts, strict=True)
            if int(label) > 0
        }
        previous_ids = {int(value) for value in np.unique(previous) if int(value) > 0}
        rough: list[tuple[float, int]] = []
        for parent in previous_ids.intersection(area_by_id):
            if parent == child or stats.get(parent, {}).get("start", start) > start - args.min_parent_age:
                continue
            py, px = ndi.center_of_mass(current == parent)
            distance = float(np.hypot(cx - px, cy - py))
            if distance <= args.max_parent_centroid_distance:
                rough.append((distance, parent))

        candidates: list[dict[str, Any]] = []
        for centroid_distance, parent in sorted(rough)[: args.max_candidates * 3]:
            contour_distance, contact = pair_geometry(child_mask, current == parent)
            if contour_distance > args.max_parent_contour_distance:
                continue
            pre_score = contour_distance + 0.03 * centroid_distance - 0.05 * min(contact, 20)
            candidates.append(
                {
                    "parent_track_id": parent,
                    "candidate_score": float(pre_score),
                    "centroid_distance": centroid_distance,
                    "contour_distance": contour_distance,
                    "contact_pixels": contact,
                    "parent_age_frames": start - int(stats[parent]["start"]),
                    "parent_area": area_by_id[parent],
                }
            )
        candidates.sort(
            key=lambda row: (
                row["candidate_score"],
                row["contour_distance"],
                row["parent_track_id"],
            )
        )
        candidates = candidates[: args.max_candidates]
        events.append(
            {
                "event_id": f"{args.roi_id}_c{child}_f{start + 1}",
                "roi": args.roi_id,
                "child_track_id": child,
                "bud_appearance_frame": start + 1,
                "target_frame_index": start,
                "lifetime": int(state["frames"]),
                "birth_area": int(state["birth_area"]),
                "candidate_count": len(candidates),
                "candidates": candidates,
            }
        )
    return events


def import_lyn(lyn_repo: Path):
    source = lyn_repo / "src"
    if not source.is_dir():
        raise FileNotFoundError(f"LYN source directory not found: {source}")
    sys.path.insert(0, str(source))
    from bread.algo.lineage import LineageGuesserNN  # type: ignore
    from bread.data import Segmentation  # type: ignore

    return LineageGuesserNN, Segmentation


def load_model_package(path: Path) -> tuple[Any, dict[str, Any], str]:
    manifest_path = path / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("features") != FEATURES:
        raise RuntimeError("Model feature order is incompatible with the builtin linker")
    for filename, expected in manifest.get("files", {}).items():
        candidate = path / filename
        if candidate.is_file() and sha256_file(candidate) != expected:
            raise RuntimeError(f"Model package hash mismatch for {filename}")
    return joblib.load(path / "hgb_lyn16.joblib"), manifest, sha256_file(manifest_path)


def finite_float(value: Any) -> float | None:
    number = float(value)
    return number if math.isfinite(number) else None


def feature_rows(
    guesser: Any, event: dict[str, Any]
) -> tuple[list[dict[str, Any]], str]:
    start = int(event["target_frame_index"])
    child = int(event["child_track_id"])
    stop = min(start + int(guesser.num_frames), len(guesser.segmentation))
    selected_times = list(range(start, stop))
    if len(selected_times) < 2:
        return [], "not_enough_frames"
    for frame in selected_times:
        if child not in guesser.segmentation.cell_ids(frame):
            return [], f"bud_missing_at_{frame + 1}"

    output: list[dict[str, Any]] = []
    for candidate in event["candidates"]:
        parent = int(candidate["parent_track_id"])
        try:
            values, _names = guesser._get_features(child, parent, start, selected_times)
            feature_values = {name: float(values[name]) for name in FEATURES}
            if not all(math.isfinite(value) for value in feature_values.values()):
                return [], f"non_finite_features_parent_{parent}"
            output.append(
                {
                    "parent_track_id": parent,
                    "features": feature_values,
                    **candidate,
                }
            )
        except Exception as exc:  # feature-level abstention is intentional
            return [], f"{type(exc).__name__}_parent_{parent}:{exc}"
    return output, ""


def margin_threshold(manifest: dict[str, Any]) -> float:
    deployment = manifest.get("deployment_calibration") or {}
    if "rank_margin_threshold" in deployment:
        return float(deployment["rank_margin_threshold"])
    return float(manifest["calibration"]["selected_rule"]["threshold"])


def load_guard(manifest: dict[str, Any]) -> tuple[bool, int | None]:
    guard = manifest.get("tracking_load_guard") or {}
    enabled = bool(guard.get("enabled", False))
    maximum = int(guard["max_new_tracks_per_frame"]) if enabled else None
    return enabled, maximum


def predict_events(
    tracks: np.ndarray,
    events: list[dict[str, Any]],
    ranker: Any,
    manifest: dict[str, Any],
    lyn_repo: Path,
    lyn_model: Path,
) -> list[dict[str, Any]]:
    LineageGuesserNN, Segmentation = import_lyn(lyn_repo)
    segmentation = Segmentation(tracks, "FOV0", preprocess=False)
    guesser = LineageGuesserNN(
        segmentation=segmentation,
        nn_threshold=12,
        num_frames=8,
        num_nn_threshold=4,
        saved_model=str(lyn_model),
    )
    threshold = margin_threshold(manifest)
    guard_enabled, max_new_tracks = load_guard(manifest)
    births = tracking_loads(tracks)
    predictions: list[dict[str, Any]] = []

    for event in events:
        base = {
            key: value
            for key, value in event.items()
            if key not in {"candidates", "target_frame_index"}
        }
        frame_index = int(event["target_frame_index"])
        new_tracks = births.get(frame_index)
        if not event["candidates"]:
            predictions.append(
                {
                    **base,
                    "status": "review",
                    "reason_code": "no_candidate",
                    "reason": "no_candidate",
                    "pred_parent_id": None,
                    "top_score": None,
                    "margin": None,
                    "new_tracks_at_birth": new_tracks,
                    "ranked_candidates": [],
                }
            )
            continue

        rows, error = feature_rows(guesser, event)
        if error or not rows:
            predictions.append(
                {
                    **base,
                    "status": "review",
                    "reason_code": "feature_error",
                    "reason": f"feature_error:{error or 'no_features'}",
                    "pred_parent_id": None,
                    "top_score": None,
                    "margin": None,
                    "new_tracks_at_birth": new_tracks,
                    "ranked_candidates": [],
                }
            )
            continue

        matrix = pd.DataFrame([row["features"] for row in rows], columns=FEATURES)
        scores = ranker.predict_proba(matrix)[:, 1]
        for row, score in zip(rows, scores, strict=True):
            row["hgb_score"] = float(score)
        ranked = sorted(rows, key=lambda row: (-row["hgb_score"], row["parent_track_id"]))
        top_score = float(ranked[0]["hgb_score"])
        second_score = float(ranked[1]["hgb_score"]) if len(ranked) > 1 else 0.0
        margin = top_score - second_score
        rank_ok = margin >= threshold
        load_ok = (
            not guard_enabled
            or (new_tracks is not None and new_tracks <= int(max_new_tracks))
        )
        if not rank_ok:
            status, reason = "review", "low_model_margin"
        elif not load_ok:
            status, reason = "review", "high_tracking_load"
        else:
            status, reason = "linked", "auto_confident"
        predictions.append(
            {
                **base,
                "status": status,
                "reason_code": reason,
                "reason": reason,
                "pred_parent_id": int(ranked[0]["parent_track_id"]),
                "top_score": top_score,
                "margin": margin,
                "new_tracks_at_birth": new_tracks,
                "ranked_candidates": [
                    {
                        key: value
                        for key, value in row.items()
                        if key != "features"
                    }
                    | {"features": row["features"]}
                    for row in ranked
                ],
            }
        )

    enforce_graph_constraints(predictions)
    return predictions


def enforce_graph_constraints(predictions: list[dict[str, Any]]) -> None:
    duplicate_children = {
        child
        for child, count in Counter(row["child_track_id"] for row in predictions).items()
        if count > 1
    }
    for row in predictions:
        if row["child_track_id"] in duplicate_children:
            row["status"] = "review"
            row["reason"] = row["reason_code"] = "duplicate_child_constraint"

    graph: dict[int, set[int]] = defaultdict(set)
    for row in predictions:
        if row["status"] == "linked" and row["pred_parent_id"] is not None:
            graph[int(row["pred_parent_id"])].add(int(row["child_track_id"]))
    visiting: set[int] = set()
    visited: set[int] = set()
    cyclic: set[int] = set()

    def visit(node: int, stack: list[int]) -> None:
        if node in visiting:
            cyclic.update(stack[stack.index(node) :] if node in stack else stack)
            return
        if node in visited:
            return
        visiting.add(node)
        stack.append(node)
        for child in graph.get(node, set()):
            visit(child, stack)
        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in list(graph):
        visit(node, [])
    for row in predictions:
        if row["child_track_id"] in cyclic or row.get("pred_parent_id") in cyclic:
            row["status"] = "review"
            row["reason"] = row["reason_code"] = "cycle_constraint"


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Builtin DetecDiv HGB-16 bud/mother inference backend."
    )
    root.add_argument("--input-h5", type=Path, required=True)
    root.add_argument("--dataset", default="/tracks")
    root.add_argument("--model-dir", type=Path, required=True)
    root.add_argument("--lyn-repo", type=Path, required=True)
    root.add_argument("--lyn-model", type=Path, required=True)
    root.add_argument("--output-json", type=Path, required=True)
    root.add_argument("--roi-id", default="roi")
    root.add_argument("--frame-end", type=int, default=-1)
    root.add_argument("--min-lifetime", type=int, default=5)
    root.add_argument("--max-birth-area", type=float, default=400)
    root.add_argument("--min-parent-age", type=int, default=2)
    root.add_argument("--max-parent-centroid-distance", type=float, default=60.0)
    root.add_argument("--max-parent-contour-distance", type=float, default=20.0)
    root.add_argument("--max-candidates", type=int, default=4)
    return root


def main() -> None:
    args = parser().parse_args()
    tracks = load_tracks(args.input_h5, args.dataset)
    if args.frame_end > 0:
        tracks = tracks[: args.frame_end]
    ranker, manifest, manifest_hash = load_model_package(args.model_dir)
    events = build_events(tracks, args)
    predictions = predict_events(
        tracks, events, ranker, manifest, args.lyn_repo, args.lyn_model
    )
    predictions.sort(
        key=lambda row: (row["bud_appearance_frame"], row["child_track_id"])
    )
    linked = [row for row in predictions if row["status"] == "linked"]
    result = {
        "schema_version": 1,
        "tool": "detecdiv_builtin_bud_mother_linker",
        "tool_version": TOOL_VERSION,
        "created_at": now(),
        "roi_id": args.roi_id,
        "input": "tracked label masks only",
        "gfp_used": False,
        "model_package": str(args.model_dir.resolve()),
        "model_manifest_sha256": manifest_hash,
        "model_tool_version": manifest.get("tool_version", "unknown"),
        "lyn_repository": str(args.lyn_repo.resolve()),
        "lyn_checkpoint_sha256": sha256_file(args.lyn_model),
        "parameters": {
            "frame_end": args.frame_end,
            "min_lifetime": args.min_lifetime,
            "max_birth_area": args.max_birth_area,
            "min_parent_age": args.min_parent_age,
            "max_parent_centroid_distance": args.max_parent_centroid_distance,
            "max_parent_contour_distance": args.max_parent_contour_distance,
            "max_candidates": args.max_candidates,
            "rank_margin_threshold": margin_threshold(manifest),
            "tracking_load_guard": load_guard(manifest),
        },
        "summary": {
            "events": len(predictions),
            "linked": len(linked),
            "review": len(predictions) - len(linked),
            "reasons": dict(
                sorted(Counter(row["reason_code"] for row in predictions).items())
            ),
        },
        "edges": predictions,
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output_json.with_suffix(args.output_json.suffix + ".tmp")
    temporary.write_text(json.dumps(result, indent=2), encoding="utf-8")
    temporary.replace(args.output_json)
    print(json.dumps(result["summary"], sort_keys=True))


if __name__ == "__main__":
    main()
