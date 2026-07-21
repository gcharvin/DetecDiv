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


def run(config_path: Path) -> None:
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    _check_cancel(cfg.get("cancel_path", ""))

    payload = loadmat(cfg["input_mat_path"])
    images = _time_first(payload["rawImages"], "rawImages")
    masks = _time_first(payload["instanceMasks"], "instanceMasks")
    if images.shape != masks.shape:
        raise ValueError(f"Image/mask shape mismatch: {images.shape} vs {masks.shape}")

    device = cfg.get("device", "automatic")
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

    graph, masks_tracked = model.track(images, masks.astype(np.int32), **kwargs)
    _check_cancel(cfg.get("cancel_path", ""))

    edge_path = Path(cfg["edge_csv_path"])
    edge_path.parent.mkdir(parents=True, exist_ok=True)
    edge_table = nx.to_pandas_edgelist(graph)
    if edge_table.empty:
        edge_table = pd.DataFrame(columns=["source", "target"])
    edge_table.to_csv(edge_path, index=False)

    matlab_masks = np.moveaxis(np.asarray(masks_tracked, dtype=np.uint32), 0, -1)
    savemat(
        cfg["output_mat_path"],
        {
            "masks_tracked": matlab_masks,
            "n_nodes": np.asarray([[graph.number_of_nodes()]], dtype=np.uint32),
            "n_edges": np.asarray([[graph.number_of_edges()]], dtype=np.uint32),
        },
        do_compression=True,
    )
    print(
        f"[Trackastra PY] frames={images.shape[0]} nodes={graph.number_of_nodes()} "
        f"edges={graph.number_of_edges()} max_tracklet={int(matlab_masks.max(initial=0))}",
        flush=True,
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: classify_trackastra.py CONFIG.json")
    run(Path(sys.argv[1]).resolve())
