import os
import json
import numpy as np
import scipy.io as sio
import torch
from cellpose import models


def load_config():
    cfg_path = os.environ.get("CPSAM_CONFIG", "")
    if not cfg_path:
        raise RuntimeError("CPSAM_CONFIG env var not set.")
    with open(cfg_path, "r", encoding="utf-8") as f:
        return json.load(f)


def extract_cellprob(flows):
    cellprob = None
    try:
        if isinstance(flows, dict):
            for k in ["cellprob", "cellprobability", "prob", "cell_probability"]:
                if k in flows:
                    cellprob = flows[k]
                    break
        elif isinstance(flows, (list, tuple)):
            if len(flows) >= 3:
                cellprob = flows[2]
            elif len(flows) >= 1:
                cellprob = flows[-1]
        else:
            cellprob = flows
    except Exception:
        cellprob = None

    if cellprob is None:
        return None
    cellprob = np.asarray(cellprob)
    cellprob = np.squeeze(cellprob)
    if cellprob.ndim == 3:
        cellprob = cellprob[-1]
    if cellprob.ndim != 2:
        return None
    return cellprob.astype(np.float32)


def main():
    cfg = load_config()

    tmp_mat_path = cfg["tmp_mat_path"]
    classif_path = cfg["classif_path"]
    model_path = cfg.get("model_path", "sam")
    gpu = bool(cfg.get("gpu", False))
    diameter = cfg.get("diameter", None)
    flow_threshold = cfg.get("flow_threshold", 0.4)
    cell_prob_threshold = cfg.get("cell_prob_threshold", 0.0)
    min_size = int(cfg.get("min_size", 10))
    mode = cfg.get("mode", "segmentation")

    print("torch.cuda.is_available():", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("GPU utilise :", torch.cuda.get_device_name(0))

    mat_data = sio.loadmat(tmp_mat_path)
    gfp = mat_data["gfp"]
    frames_list = mat_data["frames"].flatten().astype(int)

    gfp_reord = np.transpose(gfp, (3, 0, 1, 2))
    if gfp_reord.shape[-1] == 1:
        gfp_reord = np.repeat(gfp_reord, 3, axis=-1)

    images = [img.astype(np.uint8) for img in gfp_reord]

    print("Mode =", mode)
    model = models.CellposeModel(gpu=gpu, pretrained_model=model_path)
    print("Modele charge depuis :", model_path)

    H, W = images[0].shape[:2]
    masks_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.uint16)
    cellprob_all = None
    if mode == "proba":
        cellprob_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.float32)

    for i, (img, frame_idx) in enumerate(zip(images, frames_list)):
        masks, flows, styles = model.eval(
            img,
            diameter=diameter,
            channels=[0, 0],
            flow_threshold=flow_threshold,
            cellprob_threshold=cell_prob_threshold,
            min_size=min_size,
        )
        masks = np.asarray(masks, dtype=np.uint16)
        masks_all[:, :, 0, i] = masks

        if mode == "proba":
            cp = extract_cellprob(flows)
            if cp is None:
                cp = np.zeros((H, W), dtype=np.float32)
            cellprob_all[:, :, 0, i] = cp

    out = {"frames_list": frames_list, "masks_all": masks_all}
    if mode == "proba":
        out["cellprob_all"] = cellprob_all

    sio.savemat(os.path.join(classif_path, "results.mat"), out)
    print("CellposeSAM termine. Champs sauvegardes:", list(out.keys()))


if __name__ == "__main__":
    main()
