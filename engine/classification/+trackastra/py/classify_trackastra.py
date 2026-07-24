"""Stable DetecDiv bridge for Trackastra inference."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import networkx as nx
import numpy as np
import pandas as pd
from scipy.io import loadmat, savemat
from trackastra.model import Trackastra
from trackastra.model import model_api as trackastra_model_api
from trackastra.tracking.tracking import build_graph

PROGRESS_MARKER = "@@DETECDIV_PROGRESS@@"


def _report_progress(
    cfg: dict[str, object],
    local_value: float,
    message: str,
    *,
    indeterminate: bool = False,
) -> None:
    if not bool(cfg.get("progress_enabled", False)):
        return
    local_value = max(0.0, min(1.0, float(local_value)))
    base = float(cfg.get("progress_base", 0.0))
    span = float(cfg.get("progress_span", 1.0))
    payload = {
        "protocol": "detecdiv.progress.v1",
        "value": max(0.0, min(1.0, base + span * local_value)),
        "localValue": local_value,
        "message": message,
        "status": "running",
        "scope": "tracking",
        "indeterminate": bool(indeterminate),
    }
    print(
        f"{PROGRESS_MARKER} {json.dumps(payload, separators=(',', ':'))}",
        flush=True,
    )


def _time_first(array: np.ndarray, name: str) -> np.ndarray:
    value = np.asarray(array)
    if value.ndim == 2:
        value = value[..., None]
    if value.ndim != 3:
        raise ValueError(f"{name} must have MATLAB shape Y,X,T; got {value.shape}")
    return np.moveaxis(value, -1, 0)


def _check_cancel(path_value: str) -> None:
    if path_value and Path(path_value).exists():
        raise RuntimeError("Trackastra run cancelled by user")


def _track_with_gap_closing(
    model: Trackastra,
    images: np.ndarray,
    masks: np.ndarray,
    *,
    max_frame_gap: int,
    kwargs: dict[str, object],
) -> tuple[nx.DiGraph, nx.DiGraph, tuple[np.ndarray, dict[int, int]]]:
    """Run Trackastra with identical prediction/graph temporal support.

    Trackastra 0.5.3 exposes ``delta_t`` to graph construction but its private
    prediction call otherwise keeps the one-frame default.  The temporary
    wrapper makes both stages use the requested horizon while preserving the
    public model loader and feature-extractor setup.
    """

    delta_t = int(max_frame_gap) + 1
    original_predict_windows = trackastra_model_api.predict_windows
    captured: dict[str, object] = {}

    def predict_windows_with_gap(*args, **predict_kwargs):
        predict_kwargs["delta_t"] = delta_t
        predictions = original_predict_windows(*args, **predict_kwargs)
        captured["predictions"] = predictions
        return predictions

    trackastra_model_api.predict_windows = predict_windows_with_gap
    try:
        graph, _ = model.track(
            images,
            masks.astype(np.int32),
            delta_t=delta_t,
            **kwargs,
        )
    finally:
        trackastra_model_api.predict_windows = original_predict_windows
    if "predictions" not in captured:
        raise RuntimeError("Trackastra did not expose association predictions")
    predictions = captured["predictions"]
    candidate_graph = build_graph(
        nodes=predictions["nodes"],
        weights=predictions["weights"],
        use_distance=False,
        max_distance=float(kwargs.get("max_distance", 256)),
        max_neighbors=int(kwargs.get("max_neighbors", 10)),
        delta_t=delta_t,
    )
    return graph, candidate_graph, _stable_track_masks(graph, masks)


def _stable_track_masks(
    graph: nx.DiGraph, masks: np.ndarray
) -> tuple[np.ndarray, dict[int, int]]:
    """Relabel graph paths as stable track IDs, including across gaps."""

    tracked = np.zeros_like(masks, dtype=np.uint32)
    track_by_node: dict[int, int] = {}
    next_track = 1
    try:
        ordered_nodes = list(nx.lexicographical_topological_sort(graph))
    except nx.NetworkXUnfeasible as exc:
        raise ValueError("Trackastra returned a cyclic tracking graph") from exc
    for node_id in ordered_nodes:
        predecessors = list(graph.predecessors(node_id))
        if len(predecessors) == 1 and graph.out_degree(predecessors[0]) == 1:
            track_id = track_by_node[predecessors[0]]
        else:
            track_id = next_track
            next_track += 1
        track_by_node[node_id] = track_id
        node = graph.nodes[node_id]
        frame = int(node["time"])
        label = int(node["label"])
        selected = masks[frame] == label
        if not np.any(selected):
            raise ValueError(
                f"Trackastra node {node_id} references absent label {label} "
                f"in frame {frame}"
            )
        if np.any(tracked[frame][selected] != 0):
            raise ValueError(f"Overlapping Trackastra nodes in frame {frame}")
        tracked[frame][selected] = np.uint32(track_id)
    return tracked, track_by_node


def _edge_audit_table(
    graph: nx.DiGraph, track_by_node: dict[int, int]
) -> pd.DataFrame:
    rows = []
    for source, target, attributes in graph.edges(data=True):
        source_frame = int(graph.nodes[source]["time"])
        target_frame = int(graph.nodes[target]["time"])
        delta_t = target_frame - source_frame
        if graph.out_degree(source) > 1:
            edge_type = "division"
        elif delta_t > 1:
            edge_type = "gap_closing"
        else:
            edge_type = "continuation"
        rows.append(
            {
                "source_node": int(source),
                "target_node": int(target),
                "source_frame": source_frame,
                "target_frame": target_frame,
                "delta_t": delta_t,
                "edge_type": edge_type,
                "is_gap_closing": int(delta_t > 1),
                "source_track_id": int(track_by_node[source]),
                "target_track_id": int(track_by_node[target]),
                "weight": float(attributes.get("weight", np.nan)),
            }
        )
    columns = [
        "source_node",
        "target_node",
        "source_frame",
        "target_frame",
        "delta_t",
        "edge_type",
        "is_gap_closing",
        "source_track_id",
        "target_track_id",
        "weight",
    ]
    return pd.DataFrame(rows, columns=columns)


def _candidate_edge_table(
    candidate_graph: nx.DiGraph,
    solution_graph: nx.DiGraph,
    track_by_node: dict[int, int],
) -> pd.DataFrame:
    selected = set(solution_graph.edges)
    rows = []
    for source, target, attributes in candidate_graph.edges(data=True):
        source_frame = int(candidate_graph.nodes[source]["time"])
        target_frame = int(candidate_graph.nodes[target]["time"])
        delta_t = target_frame - source_frame
        rows.append(
            {
                "source_node": int(source),
                "target_node": int(target),
                "source_frame": source_frame,
                "target_frame": target_frame,
                "delta_t": delta_t,
                "is_gap_candidate": int(delta_t > 1),
                "source_label": int(candidate_graph.nodes[source]["label"]),
                "target_label": int(candidate_graph.nodes[target]["label"]),
                "source_track_id": int(track_by_node.get(source, 0)),
                "target_track_id": int(track_by_node.get(target, 0)),
                "weight": float(attributes.get("weight", np.nan)),
                "selected": int((source, target) in selected),
            }
        )
    columns = [
        "source_node",
        "target_node",
        "source_frame",
        "target_frame",
        "delta_t",
        "is_gap_candidate",
        "source_label",
        "target_label",
        "source_track_id",
        "target_track_id",
        "weight",
        "selected",
    ]
    return pd.DataFrame(rows, columns=columns)


def run(config_path: Path) -> None:
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    _check_cancel(cfg.get("cancel_path", ""))
    _report_progress(
        cfg, 0, "Loading Trackastra inputs...", indeterminate=True
    )

    payload = loadmat(cfg["input_mat_path"])
    images = _time_first(payload["rawImages"], "rawImages")
    masks = _time_first(payload["instanceMasks"], "instanceMasks")
    if images.shape != masks.shape:
        raise ValueError(f"Image/mask shape mismatch: {images.shape} vs {masks.shape}")

    device = cfg.get("device", "automatic")
    _report_progress(
        cfg, 0, "Loading Trackastra model...", indeterminate=True
    )
    if cfg.get("model_source", "pretrained") == "custom":
        model_path = cfg.get("custom_model_path", "")
        if not model_path:
            raise ValueError("custom_model_path is required when model_source=custom")
        checkpoint = cfg.get("checkpoint_path") or None
        model = Trackastra.from_folder(
            Path(model_path), device=device, checkpoint_path=checkpoint
        )
    else:
        model_name = cfg.get("pretrained_model") or "general_2d"
        model = Trackastra.from_pretrained(model_name, device=device)

    kwargs: dict[str, object] = {
        "mode": cfg.get("tracking_mode", "greedy"),
        "normalize_imgs": bool(cfg.get("normalize_images", True)),
        "n_workers": int(cfg.get("n_workers", 0)),
    }
    batch_size = int(cfg.get("batch_size", 0))
    if batch_size > 0:
        kwargs["batch_size"] = batch_size
    max_distance = float(cfg.get("max_distance", 0))
    if max_distance > 0:
        kwargs["max_distance"] = max_distance

    _report_progress(
        cfg,
        0,
        f"Tracking {images.shape[0]} frames with Trackastra...",
        indeterminate=True,
    )
    max_frame_gap = max(0, int(cfg.get("max_frame_gap", 1)))
    graph, candidate_graph, (masks_tracked, track_by_node) = _track_with_gap_closing(
        model,
        images,
        masks,
        max_frame_gap=max_frame_gap,
        kwargs=kwargs,
    )
    _check_cancel(cfg.get("cancel_path", ""))

    edge_path = Path(cfg["edge_csv_path"])
    edge_path.parent.mkdir(parents=True, exist_ok=True)
    edge_table = _edge_audit_table(graph, track_by_node)
    edge_table.to_csv(edge_path, index=False)
    n_gap_edges = int(edge_table["is_gap_closing"].sum())
    candidate_edge_path = Path(cfg["candidate_edge_csv_path"])
    candidate_edge_path.parent.mkdir(parents=True, exist_ok=True)
    candidate_edges = _candidate_edge_table(
        candidate_graph, graph, track_by_node
    )
    candidate_edges.to_csv(candidate_edge_path, index=False)

    matlab_masks = np.moveaxis(np.asarray(masks_tracked, dtype=np.uint32), 0, -1)
    savemat(
        cfg["output_mat_path"],
        {
            "masks_tracked": matlab_masks,
            "n_nodes": np.asarray([[graph.number_of_nodes()]], dtype=np.uint32),
            "n_edges": np.asarray([[graph.number_of_edges()]], dtype=np.uint32),
            "n_gap_edges": np.asarray([[n_gap_edges]], dtype=np.uint32),
            "n_candidate_edges": np.asarray(
                [[len(candidate_edges)]], dtype=np.uint32
            ),
        },
        do_compression=True,
    )
    print(
        f"[Trackastra PY] frames={images.shape[0]} nodes={graph.number_of_nodes()} "
        f"edges={graph.number_of_edges()} candidates={len(candidate_edges)} "
        f"gap_edges={n_gap_edges} "
        f"max_tracklet={int(matlab_masks.max(initial=0))}",
        flush=True,
    )
    _report_progress(
        cfg,
        1,
        f"Tracked {images.shape[0]} frames "
        f"({graph.number_of_nodes()} nodes, {graph.number_of_edges()} edges)",
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: classify_trackastra.py CONFIG.json")
    run(Path(sys.argv[1]).resolve())
