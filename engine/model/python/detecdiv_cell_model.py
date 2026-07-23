"""Reader/query helpers for DetecDiv ``objects_<roi>.h5`` schema v1.

Masks remain in the ROI image HDF5.  This sidecar only contains compact
references to ``(family_id, frame, mask_label)`` plus track/state/lineage data.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import h5py
import numpy as np


INSTANCE_DTYPES = {
    "object_id": np.uint64,
    "family_id": np.uint32,
    "frame": np.uint32,
    "mask_label": np.uint32,
    "track_id": np.uint64,
    "state_id": np.uint16,
}

RELATION_DTYPES = {
    "relation_id": np.uint64,
    "family_id": np.uint32,
    "parent_track_id": np.uint64,
    "child_track_id": np.uint64,
    "event_frame": np.uint32,
    "type_id": np.uint8,
    "confidence": np.float32,
}


def load(path: str | Path) -> dict[str, Any]:
    """Load and validate a DetecDiv cellular object model."""
    path = Path(path)
    with h5py.File(path, "r") as handle:
        metadata_bytes = np.asarray(handle["metadata_json"], dtype=np.uint8).tobytes()
        metadata = json.loads(metadata_bytes.decode("utf-8"))
        if metadata.get("format") != "detecdiv_cell_model":
            raise ValueError(f"Not a DetecDiv cell model: {path}")
        if int(metadata.get("schema_version", -1)) != 1:
            raise ValueError(f"Unsupported schema version in {path}")
        model = dict(metadata)
        for name in ("families", "states", "relation_types"):
            value = model.get(name, [])
            if isinstance(value, dict):
                model[name] = [value]
            elif value is None:
                model[name] = []
        model["instances"] = _read_columns(handle, "instances", INSTANCE_DTYPES)
        model["relations"] = _read_columns(handle, "relations", RELATION_DTYPES)
    validate(model)
    return model


def validate(model: dict[str, Any]) -> None:
    """Raise ``ValueError`` when core IDs/references are inconsistent."""
    instances = model["instances"]
    relations = model["relations"]
    family_ids = np.asarray(
        [family["family_id"] for family in model.get("families", [])], dtype=np.uint32
    )
    if np.any(family_ids == 0) or len(np.unique(family_ids)) != len(family_ids):
        raise ValueError("family_id values must be positive and unique")
    n_instances = len(instances["object_id"])
    if any(len(values) != n_instances for values in instances.values()):
        raise ValueError("Instance columns have different lengths")
    if len(np.unique(instances["object_id"])) != n_instances:
        raise ValueError("object_id values must be unique")
    if np.any(instances["object_id"] == 0):
        raise ValueError("object_id values must be positive")
    if np.any(instances["frame"] == 0) or np.any(instances["mask_label"] == 0):
        raise ValueError("Frames and mask labels are 1-based/positive")
    if np.any(~np.isin(instances["family_id"], family_ids)):
        raise ValueError("Instances reference unknown families")
    keys = np.column_stack(
        (instances["family_id"], instances["frame"], instances["mask_label"])
    )
    if len(keys) and len(np.unique(keys, axis=0)) != len(keys):
        raise ValueError("Duplicate (family_id, frame, mask_label) reference")
    tracked = instances["track_id"] != 0
    track_frame_keys = np.column_stack(
        (
            instances["family_id"][tracked],
            instances["frame"][tracked],
            instances["track_id"][tracked],
        )
    )
    if len(track_frame_keys) and len(np.unique(track_frame_keys, axis=0)) != len(
        track_frame_keys
    ):
        raise ValueError("A track maps to several labels in one family/frame")

    n_relations = len(relations["relation_id"])
    if any(len(values) != n_relations for values in relations.values()):
        raise ValueError("Relation columns have different lengths")
    if len(np.unique(relations["relation_id"])) != n_relations:
        raise ValueError("relation_id values must be unique")
    if np.any(~np.isin(relations["family_id"], family_ids)):
        raise ValueError("Relations reference unknown families")
    if np.any(relations["parent_track_id"] == relations["child_track_id"]):
        raise ValueError("A track cannot be its own parent")
    parent_rows = relations["type_id"] == 1
    child_keys = np.column_stack(
        (relations["family_id"][parent_rows], relations["child_track_id"][parent_rows])
    )
    if len(child_keys) and len(np.unique(child_keys, axis=0)) != len(child_keys):
        raise ValueError("A child track has more than one parent in one family")


def instances_for_frame(
    model: dict[str, Any], family_id: int, frame: int
) -> dict[str, np.ndarray]:
    """Return column arrays for one family/frame without copying unrelated rows."""
    instances = model["instances"]
    keep = (instances["family_id"] == family_id) & (instances["frame"] == frame)
    return {name: values[keep] for name, values in instances.items()}


def family_by_name(model: dict[str, Any], name: str) -> dict[str, Any] | None:
    """Return family metadata by exact name."""
    for family in model.get("families", []):
        if family.get("name") == name:
            return family
    return None


def _read_columns(
    handle: h5py.File, group_name: str, dtypes: dict[str, np.dtype]
) -> dict[str, np.ndarray]:
    group = handle.get(group_name)
    output: dict[str, np.ndarray] = {}
    for name, dtype in dtypes.items():
        if group is None or name not in group:
            output[name] = np.empty(0, dtype=dtype)
        else:
            output[name] = np.asarray(group[name], dtype=dtype).reshape(-1)
    return output
