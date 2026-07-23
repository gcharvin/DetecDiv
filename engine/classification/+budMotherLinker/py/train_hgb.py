"""Train sklearn HistGradientBoosting and export its trees for MATLAB."""

from __future__ import annotations

import argparse
import json
import platform
from pathlib import Path

import numpy as np
import scipy
from scipy.io import loadmat, savemat
import sklearn
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.preprocessing import StandardScaler


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    return parser.parse_args()


def export_trees(model: HistGradientBoostingClassifier) -> dict[str, np.ndarray]:
    predictors = [iteration[0] for iteration in model._predictors]
    node_count = np.asarray([len(tree.nodes) for tree in predictors], dtype=np.uint16)
    max_nodes = int(node_count.max(initial=0))
    shape = (len(predictors), max_nodes)

    feature_idx = np.zeros(shape, dtype=np.int16)
    threshold = np.zeros(shape, dtype=np.float64)
    left = np.zeros(shape, dtype=np.uint16)
    right = np.zeros(shape, dtype=np.uint16)
    value = np.zeros(shape, dtype=np.float64)
    is_leaf = np.ones(shape, dtype=np.uint8)
    missing_go_left = np.zeros(shape, dtype=np.uint8)

    for row, predictor in enumerate(predictors):
        nodes = predictor.nodes
        count = len(nodes)
        # MATLAB indices are one-based. Leaf child/feature values stay zero.
        nonleaf = nodes["is_leaf"] == 0
        feature_idx[row, :count][nonleaf] = (
            nodes["feature_idx"][nonleaf].astype(np.int16) + 1
        )
        threshold[row, :count] = nodes["num_threshold"]
        left[row, :count][nonleaf] = nodes["left"][nonleaf].astype(np.uint16) + 1
        right[row, :count][nonleaf] = nodes["right"][nonleaf].astype(np.uint16) + 1
        value[row, :count] = nodes["value"]
        is_leaf[row, :count] = nodes["is_leaf"].astype(np.uint8)
        missing_go_left[row, :count] = nodes["missing_go_to_left"].astype(np.uint8)

    return {
        "baseline": np.asarray(model._baseline_prediction, dtype=np.float64).reshape(1, 1),
        "feature_idx": feature_idx,
        "threshold": threshold,
        "left": left,
        "right": right,
        "value": value,
        "is_leaf": is_leaf,
        "missing_go_left": missing_go_left,
        "node_count": node_count.reshape(1, -1),
    }


def main() -> None:
    args = parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8"))
    input_path = Path(config["input_path"])
    output_path = Path(config["output_path"])
    report_path = Path(config["report_path"])

    payload = loadmat(input_path)
    x = np.asarray(payload["X"], dtype=np.float64)
    y = np.asarray(payload["y"]).reshape(-1).astype(np.int64)
    train_rows = np.asarray(payload["train_rows"]).reshape(-1).astype(bool)
    if x.ndim != 2 or x.shape[0] != y.size or train_rows.size != y.size:
        raise ValueError("Training matrix, labels, and split mask have incompatible shapes")
    if not np.isfinite(x).all():
        raise ValueError("Training matrix contains non-finite descriptors")
    if np.unique(y[train_rows]).size != 2:
        raise ValueError("Training split must contain both candidate-link classes")

    scaler = StandardScaler()
    scaler.fit(x[train_rows])
    normalized = scaler.transform(x)
    params = config["parameters"]
    model = HistGradientBoostingClassifier(
        max_iter=int(params["max_iter"]),
        learning_rate=float(params["learning_rate"]),
        max_leaf_nodes=int(params["max_leaf_nodes"]),
        min_samples_leaf=int(params["min_samples_leaf"]),
        l2_regularization=float(params["l2_regularization"]),
        early_stopping=False,
        random_state=int(params["random_state"]),
    )
    model.fit(normalized[train_rows], y[train_rows])
    scores = model.predict_proba(normalized)[:, 1]
    raw_scores = model.decision_function(normalized)

    exported = export_trees(model)
    exported.update(
        {
            "feature_mean": scaler.mean_.reshape(1, -1),
            "feature_scale": scaler.scale_.reshape(1, -1),
            "python_scores": scores.reshape(-1, 1),
            "python_raw_scores": raw_scores.reshape(-1, 1),
        }
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    savemat(output_path, exported, do_compression=True, oned_as="row")

    report = {
        "status": "OK",
        "model_type": "sklearn.ensemble.HistGradientBoostingClassifier",
        "python_version": platform.python_version(),
        "numpy_version": np.__version__,
        "scipy_version": scipy.__version__,
        "sklearn_version": sklearn.__version__,
        "parameters": {
            **params,
            "early_stopping": False,
        },
        "training_rows": int(train_rows.sum()),
        "positive_training_rows": int(y[train_rows].sum()),
        "candidate_rows": int(y.size),
        "trees": int(len(model._predictors)),
        "max_nodes": int(exported["feature_idx"].shape[1]),
        "output_path": str(output_path.resolve()),
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
