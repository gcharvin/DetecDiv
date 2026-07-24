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
    candidates.add_edge(0, 2, weight=0.2)
    table = MODULE._candidate_edge_table(candidates, graph, track_by_node)
    skipped = table[(table.source_node == 0) & (table.target_node == 2)].iloc[0]
    assert skipped.delta_t == 3
    assert skipped.is_gap_candidate == 1
    assert skipped.selected == 0
