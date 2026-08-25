import importlib.util
from pathlib import Path

import networkx as nx
import numpy as np


MODULE_PATH = Path(__file__).with_name("classify_trackastra.py")
SPEC = importlib.util.spec_from_file_location("detecdiv_trackastra_runner", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def synthetic_graph_and_masks():
    graph = nx.DiGraph()
    nodes = [
        (0, 0, 1),
        (1, 1, 3),
        (2, 3, 7),
        (3, 4, 2),
        (4, 4, 5),
    ]
    for node_id, frame, label in nodes:
        graph.add_node(node_id, time=frame, label=label)
    graph.add_edge(0, 1, weight=0.9)
    graph.add_edge(1, 2, weight=0.8)
    graph.add_edge(2, 3, weight=0.7)
    graph.add_edge(2, 4, weight=0.6)
    masks = np.zeros((5, 4, 4), dtype=np.uint16)
    for _, frame, label in nodes:
        masks[frame, label % 4, label % 3] = label
    return graph, masks


def test_gap_keeps_one_stable_track_and_division_starts_children():
    graph, masks = synthetic_graph_and_masks()
    tracked, track_by_node = MODULE._stable_track_masks(graph, masks)
    assert track_by_node[0] == track_by_node[1] == track_by_node[2] == 1
    assert track_by_node[3] == 2
    assert track_by_node[4] == 3
    assert tracked[2].max() == 0
    assert 1 in tracked[3]


def test_isolated_candidate_detection_is_preserved_as_singleton_track():
    selected = nx.DiGraph()
    selected.add_node(0, time=0, label=1)
    candidates = selected.copy()
    candidates.add_node(1, time=1, label=2)
    masks = np.zeros((2, 5, 5), dtype=np.uint16)
    masks[0, 1:3, 1:3] = 1
    masks[1, 2:4, 2:4] = 2

    MODULE._preserve_isolated_detections(selected, candidates)
    tracked, track_by_node = MODULE._stable_track_masks(selected, masks)

    assert set(selected.nodes) == {0, 1}
    assert track_by_node[0] != track_by_node[1]
    assert np.array_equal(tracked > 0, masks > 0)


def test_edge_audit_marks_gap_and_division():
    graph, masks = synthetic_graph_and_masks()
    _, track_by_node = MODULE._stable_track_masks(graph, masks)
    table = MODULE._edge_audit_table(graph, track_by_node)
    gap = table[(table.source_node == 1) & (table.target_node == 2)].iloc[0]
    assert gap.delta_t == 2
    assert gap.edge_type == "gap_closing"
    assert gap.source_track_id == gap.target_track_id
    divisions = table[table.edge_type == "division"]
    assert len(divisions) == 2
    assert all(divisions.source_track_id != divisions.target_track_id)


def test_candidate_table_preserves_unselected_probabilistic_edges():
    graph, masks = synthetic_graph_and_masks()
    _, track_by_node = MODULE._stable_track_masks(graph, masks)
    candidates = graph.copy()
    candidates.add_edge(
        0,
        2,
        weight=0.2,
        division_candidate=True,
        geometric_birth_candidate=True,
        trackastra_score=0.2,
        lyn_logit=-0.4,
        lyn_percentile=0.6,
        producer_trackastra=True,
        producer_lyn=True,
        agreement=True,
        fusion_method="fixed_max",
        fusion_calibrated_probability=0.7,
    )
    table = MODULE._candidate_edge_table(candidates, graph, track_by_node)
    skipped = table[(table.source_node == 0) & (table.target_node == 2)].iloc[0]
    assert skipped.delta_t == 3
    assert skipped.is_gap_candidate == 1
    assert skipped.division_candidate == 1
    assert skipped.geometric_birth_candidate == 1
    assert skipped.trackastra_score == 0.2
    assert skipped.lyn_logit == -0.4
    assert skipped.lyn_percentile == 0.6
    assert skipped.producer_trackastra == 1
    assert skipped.producer_lyn == 1
    assert skipped.agreement == 1
    assert skipped.fusion_method == "fixed_max"
    assert skipped.fusion_calibrated_probability == 0.7
    assert skipped.selected == 0


def test_asymmetric_division_preserves_spatially_continuous_mother():
    graph = nx.DiGraph()
    graph.add_node(0, time=0, label=1)
    graph.add_node(1, time=1, label=2)
    graph.add_node(2, time=1, label=3)
    graph.add_edge(0, 1, weight=0.8)
    graph.add_edge(0, 2, weight=0.9)
    masks = np.zeros((2, 8, 8), dtype=np.uint16)
    masks[0, 2:5, 2:5] = 1
    masks[1, 2:5, 3:6] = 2
    masks[1, 5:7, 1:3] = 3
    _, tracks = MODULE._stable_track_masks(
        graph, masks, division_identity_mode="continuing_parent"
    )
    assert tracks[0] == tracks[1]
    assert tracks[2] != tracks[0]


def test_joint_decode_rebuilds_selected_graph(monkeypatch):
    graph, masks = synthetic_graph_and_masks()
    graph.edges[0, 1]["division_weight"] = 0.73
    graph.edges[0, 1]["division_candidate"] = True
    graph.edges[0, 1]["trackastra_score"] = 0.9
    graph.edges[0, 1]["lyn_logit"] = 1.4
    graph.edges[0, 1]["lyn_percentile"] = 0.85
    graph.edges[0, 1]["producer_trackastra"] = True
    graph.edges[0, 1]["producer_lyn"] = True
    graph.edges[0, 1]["agreement"] = True
    graph.edges[0, 1]["fusion_method"] = "fixed_max"

    def fake_decode(**kwargs):
        assert len(kwargs["nodes"]) == graph.number_of_nodes()
        assert len(kwargs["edges"]) == graph.number_of_edges()
        first = next(
            row
            for row in kwargs["edges"]
            if row["source"] == 0 and row["target"] == 1
        )
        assert first["score"] == 0.9
        assert first["division_score"] == 0.73
        assert first["division_candidate"]
        assert first["trackastra_score"] == 0.9
        assert first["lyn_logit"] == 1.4
        assert first["lyn_percentile"] == 0.85
        assert first["producer_trackastra"]
        assert first["producer_lyn"]
        assert first["agreement"]
        assert first["fusion_method"] == "fixed_max"
        assert kwargs["package_path"].name == (
            "moma_division_hgb_birth_augmented_v003"
        )
        return {
            "selected_edges": [
                {"source": 0, "target": 1, "score": 0.9},
                {"source": 1, "target": 2, "score": 0.8},
            ],
            "selected_divisions": [],
            "selected_division_count": 0,
        }

    import cell_latent_model

    monkeypatch.setattr(
        cell_latent_model, "decode_tracking_lineage", fake_decode
    )
    selected, report = MODULE._joint_decode(
        graph,
        masks.astype(np.float32),
        masks,
        "synthetic",
    )
    assert set(selected.edges) == {(0, 1), (1, 2)}
    assert report["selected_division_count"] == 0


def test_joint_decode_accepts_frozen_division_package(monkeypatch, tmp_path):
    graph, masks = synthetic_graph_and_masks()
    package = tmp_path / "frozen_division_head"

    def fake_decode(**kwargs):
        assert kwargs["package_path"] == package
        return {
            "selected_edges": [],
            "selected_divisions": [],
            "selected_division_count": 0,
        }

    import cell_latent_model

    monkeypatch.setattr(
        cell_latent_model, "decode_tracking_lineage", fake_decode
    )
    MODULE._joint_decode(
        graph,
        masks.astype(np.float32),
        masks,
        "synthetic",
        package_path=package,
    )


def test_joint_decode_forwards_permissive_birth_policy(monkeypatch):
    graph, masks = synthetic_graph_and_masks()

    def fake_decode(**kwargs):
        assert kwargs["division_proposal_policy"] == "top_per_source"
        assert kwargs["max_accepted_divisions_per_1000_nodes"] is None
        return {
            "selected_edges": [],
            "selected_divisions": [],
            "selected_division_count": 0,
        }

    import cell_latent_model

    monkeypatch.setattr(
        cell_latent_model, "decode_tracking_lineage", fake_decode
    )
    MODULE._joint_decode(
        graph,
        masks.astype(np.float32),
        masks,
        "synthetic",
        division_proposal_policy="top_per_source",
        max_accepted_divisions_per_1000_nodes=None,
    )


def test_typed_mother_override_controls_track_identity():
    graph = nx.DiGraph()
    graph.add_node(0, time=0, label=1)
    graph.add_node(1, time=1, label=2)
    graph.add_node(2, time=1, label=3)
    graph.add_edge(0, 1, weight=0.8)
    graph.add_edge(0, 2, weight=0.9)
    masks = np.zeros((2, 8, 8), dtype=np.uint16)
    masks[0, 2:5, 2:5] = 1
    masks[1, 2:5, 3:6] = 2
    masks[1, 5:7, 1:3] = 3
    _, tracks = MODULE._stable_track_masks(
        graph,
        masks,
        division_identity_mode="continuing_parent",
        continuing_child_override={0: 2},
    )
    assert tracks[2] == tracks[0]
    assert tracks[1] != tracks[0]
