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
    division_identity_mode: str = "continuing_parent",
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
    return graph, candidate_graph, _stable_track_masks(
        graph, masks, division_identity_mode=division_identity_mode
    )


def _stable_track_masks(
    graph: nx.DiGraph,
    masks: np.ndarray,
    *,
    division_identity_mode: str = "symmetric",
    continuing_child_override: dict[int, int] | None = None,
) -> tuple[np.ndarray, dict[int, int]]:
    """Relabel graph paths as stable track IDs, including across gaps."""

    if division_identity_mode not in {"symmetric", "continuing_parent"}:
        raise ValueError(
            f"Unsupported division identity mode: {division_identity_mode}"
        )
    tracked = np.zeros_like(masks, dtype=np.uint32)
    track_by_node: dict[int, int] = {}
    continuing_child: dict[int, int] = {}
    if division_identity_mode == "continuing_parent":
        continuing_child = (
            dict(continuing_child_override)
            if continuing_child_override is not None
            else _continuing_children(graph, masks)
        )
    next_track = 1
    try:
        ordered_nodes = list(nx.lexicographical_topological_sort(graph))
    except nx.NetworkXUnfeasible as exc:
        raise ValueError("Trackastra returned a cyclic tracking graph") from exc
    nodes_by_frame: dict[int, list[tuple[int, int, int]]] = {}
    for node_id in ordered_nodes:
        predecessors = list(graph.predecessors(node_id))
        if len(predecessors) == 1:
            predecessor = predecessors[0]
            inherits = graph.out_degree(predecessor) == 1 or (
                continuing_child.get(predecessor) == node_id
            )
            track_id = (
                track_by_node[predecessor] if inherits else next_track
            )
            if not inherits:
                next_track += 1
        else:
            track_id = next_track
            next_track += 1
        track_by_node[node_id] = track_id
        node = graph.nodes[node_id]
        frame = int(node["time"])
        label = int(node["label"])
        nodes_by_frame.setdefault(frame, []).append(
            (int(node_id), label, track_id)
        )

    for frame, rows in nodes_by_frame.items():
        plane = np.asarray(masks[frame])
        maximum_label = int(np.max(plane, initial=0))
        counts = np.bincount(
            np.asarray(plane, dtype=np.int64).ravel(),
            minlength=maximum_label + 1,
        )
        label_to_track = np.zeros(maximum_label + 1, dtype=np.uint32)
        for node_id, label, track_id in rows:
            if label < 0 or label > maximum_label or counts[label] == 0:
                raise ValueError(
                    f"Trackastra node {node_id} references absent label {label} "
                    f"in frame {frame}"
                )
            if label_to_track[label] != 0:
                raise ValueError(
                    f"Overlapping Trackastra nodes in frame {frame}"
                )
            label_to_track[label] = np.uint32(track_id)
        tracked[frame] = label_to_track[
            np.asarray(plane, dtype=np.int64)
        ]
    return tracked, track_by_node


def _continuing_children(
    graph: nx.DiGraph, masks: np.ndarray
) -> dict[int, int]:
    """Choose the spatially continuous successor at asymmetric divisions."""

    selected: dict[int, int] = {}
    for source in graph.nodes:
        successors = list(graph.successors(source))
        if len(successors) <= 1:
            continue
        source_node = graph.nodes[source]
        source_mask = (
            masks[int(source_node["time"])] == int(source_node["label"])
        )
        source_y, source_x = np.nonzero(source_mask)
        source_centre = np.asarray(
            [source_y.mean(), source_x.mean()], dtype=np.float64
        )
        ranked: list[tuple[float, float, float, int]] = []
        for target in successors:
            target_node = graph.nodes[target]
            target_mask = (
                masks[int(target_node["time"])] == int(target_node["label"])
            )
            intersection = int(np.count_nonzero(source_mask & target_mask))
            union = int(np.count_nonzero(source_mask | target_mask))
            iou = intersection / union if union else 0.0
            target_y, target_x = np.nonzero(target_mask)
            target_centre = np.asarray(
                [target_y.mean(), target_x.mean()], dtype=np.float64
            )
            distance = float(np.linalg.norm(target_centre - source_centre))
            weight = float(graph.edges[source, target].get("weight", 0.0))
            ranked.append((-iou, distance, -weight, int(target)))
        selected[int(source)] = min(ranked)[3]
    return selected


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
                "division_weight": float(
                    attributes.get("division_weight", np.nan)
                ),
                "division_candidate": int(
                    bool(attributes.get("division_candidate", False))
                ),
                "proposal_only": int(
                    bool(attributes.get("proposal_only", False))
                ),
                "geometric_birth_candidate": int(
                    bool(
                        attributes.get(
                            "geometric_birth_candidate", False
                        )
                    )
                ),
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
        "division_weight",
        "division_candidate",
        "proposal_only",
        "geometric_birth_candidate",
        "selected",
    ]
    return pd.DataFrame(rows, columns=columns)


def _joint_decode(
    candidate_graph: nx.DiGraph,
    images: np.ndarray,
    masks: np.ndarray,
    roi_id: str,
    package_path: str | Path | None = None,
    solver_parameters: dict[str, object] | None = None,
) -> tuple[nx.DiGraph, dict[str, object]]:
    """Apply the packaged latent division head before stable track collapse."""

    from cell_latent_model import (
        decode_tracking_lineage,
        default_budding_hgb_division_package_path,
    )

    nodes = [
        {
            "node": int(node),
            "frame": int(attributes["time"]),
            "label": int(attributes["label"]),
        }
        for node, attributes in candidate_graph.nodes(data=True)
    ]
    edges = [
        {
            "source": int(source),
            "target": int(target),
            "score": float(attributes.get("weight", 0.0)),
            "division_score": float(
                attributes.get(
                    "division_weight",
                    attributes.get("weight", 0.0),
                )
            ),
            "division_candidate": bool(
                attributes.get("division_candidate", True)
            ),
        }
        for source, target, attributes in candidate_graph.edges(data=True)
    ]
    uses_budding_proposal = any(
        bool(attributes.get("division_candidate", False))
        for _, _, attributes in candidate_graph.edges(data=True)
    )
    report = decode_tracking_lineage(
        roi_id=roi_id,
        images=images,
        masks=masks,
        nodes=nodes,
        edges=edges,
        solver_parameters=solver_parameters,
        package_path=(
            package_path
            if package_path is not None
            else (
                default_budding_hgb_division_package_path()
                if uses_budding_proposal
                else None
            )
        ),
    )
    report["budding_proposal_enabled"] = uses_budding_proposal
    graph = nx.DiGraph()
    graph.add_nodes_from(candidate_graph.nodes(data=True))
    for edge in report["selected_edges"]:
        source = int(edge["source"])
        target = int(edge["target"])
        graph.add_edge(
            source,
            target,
            **dict(candidate_graph.edges[source, target]),
        )
    return graph, report


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
    budding_proposal_enabled = bool(
        cfg.get("budding_proposal_enabled", False)
    )
    if (
        cfg.get("model_source", "pretrained") == "custom"
        and not budding_proposal_enabled
    ):
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

    proposal_model = None
    if budding_proposal_enabled:
        if not bool(cfg.get("joint_decoder_enabled", False)):
            raise ValueError(
                "budding_proposal_enabled requires joint_decoder_enabled"
            )
        if cfg.get("model_source", "pretrained") == "custom":
            proposal_path = cfg.get("custom_model_path", "")
            if not proposal_path:
                raise ValueError(
                    "custom_model_path is required for a custom budding "
                    "proposal"
                )
            proposal_checkpoint = cfg.get("checkpoint_path") or None
        else:
            from cell_latent_model import (
                default_budding_trackastra_model_path,
            )

            proposal_path = default_budding_trackastra_model_path()
            proposal_checkpoint = None
        proposal_model = Trackastra.from_folder(
            Path(proposal_path),
            device=device,
            checkpoint_path=proposal_checkpoint,
        )

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
        division_identity_mode=str(
            cfg.get("division_identity_mode", "continuing_parent")
        ),
        kwargs=kwargs,
    )
    base_candidate_count = candidate_graph.number_of_edges()
    proposal_candidate_count = 0
    proposal_only_candidate_count = 0
    geometric_birth_candidate_count = 0
    if proposal_model is not None:
        _report_progress(
            cfg,
            0.72,
            "Proposing budding-specific temporal links...",
            indeterminate=True,
        )
        _, proposal_graph, _ = _track_with_gap_closing(
            proposal_model,
            images,
            masks,
            max_frame_gap=max_frame_gap,
            division_identity_mode="continuing_parent",
            kwargs=kwargs,
        )
        from cell_latent_model import merge_proposal_candidates

        proposal_candidate_count = proposal_graph.number_of_edges()
        candidate_graph = merge_proposal_candidates(
            candidate_graph,
            proposal_graph,
        )
        from cell_latent_model import augment_budding_birth_candidates

        candidate_graph = augment_budding_birth_candidates(
            candidate_graph,
            masks,
        )
        proposal_only_candidate_count = sum(
            bool(attributes.get("proposal_only", False))
            for _, _, attributes in candidate_graph.edges(data=True)
        )
        geometric_birth_candidate_count = sum(
            bool(attributes.get("geometric_birth_candidate", False))
            for _, _, attributes in candidate_graph.edges(data=True)
        )
    joint_report = None
    if bool(cfg.get("joint_decoder_enabled", False)):
        _report_progress(
            cfg,
            0.92,
            "Jointly decoding tracking and divisions...",
            indeterminate=True,
        )
        graph, joint_report = _joint_decode(
            candidate_graph,
            images,
            masks,
            str(cfg.get("roi_id", "roi")),
        )
        typed_mother = {
            int(row["source"]): int(row["mother"])
            for row in joint_report["selected_divisions"]
        }
        masks_tracked, track_by_node = _stable_track_masks(
            graph,
            masks,
            division_identity_mode="continuing_parent",
            continuing_child_override=typed_mother,
        )
        lineage_edges = []
        for division in joint_report["selected_divisions"]:
            source = int(division["source"])
            mother = int(division["mother"])
            bud = int(division["bud"])
            lineage_edges.append(
                {
                    "status": "linked",
                    "pred_parent_id": int(track_by_node[source]),
                    "child_track_id": int(track_by_node[bud]),
                    "bud_appearance_frame": (
                        int(candidate_graph.nodes[bud]["time"]) + 1
                    ),
                    "top_score": float(division["score"]),
                    "source_node": source,
                    "mother_node": mother,
                    "bud_node": bud,
                }
            )
        joint_report["lineage_edges"] = lineage_edges
        joint_path = Path(cfg["joint_report_path"])
        joint_path.parent.mkdir(parents=True, exist_ok=True)
        joint_path.write_text(
            json.dumps(joint_report, indent=2), encoding="utf-8"
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
            "n_base_candidate_edges": np.asarray(
                [[base_candidate_count]], dtype=np.uint32
            ),
            "n_proposal_candidate_edges": np.asarray(
                [[proposal_candidate_count]], dtype=np.uint32
            ),
            "n_proposal_only_candidate_edges": np.asarray(
                [[proposal_only_candidate_count]], dtype=np.uint32
            ),
            "n_geometric_birth_candidate_edges": np.asarray(
                [[geometric_birth_candidate_count]], dtype=np.uint32
            ),
            "n_joint_divisions": np.asarray(
                [[
                    int(joint_report["selected_division_count"])
                    if joint_report is not None
                    else 0
                ]],
                dtype=np.uint32,
            ),
        },
        do_compression=True,
    )
    print(
        f"[Trackastra PY] frames={images.shape[0]} nodes={graph.number_of_nodes()} "
        f"edges={graph.number_of_edges()} candidates={len(candidate_edges)} "
        f"gap_edges={n_gap_edges} "
        f"joint_divisions={int(joint_report['selected_division_count']) if joint_report else 0} "
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
