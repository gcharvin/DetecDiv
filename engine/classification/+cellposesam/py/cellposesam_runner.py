import os
import json
import traceback
import numpy as np
import scipy.io as sio
import torch
from cellpose import models

MODEL = None
MODEL_PATH = None
MODEL_GPU = None


def load_config(cfg_path=None):
    if cfg_path is None:
        cfg_path = os.environ.get("CPSAM_CONFIG", "")
    if not cfg_path:
        raise RuntimeError("CPSAM_CONFIG env var not set and no cfg_path provided.")
    with open(cfg_path, "r", encoding="utf-8") as f:
        return json.load(f)


def to_float(v, default=None):
    if v is None:
        return default
    if isinstance(v, str):
        vs = v.strip().lower()
        if vs in ["", "nan", "none", "null"]:
            return default
        return float(vs)
    return float(v)


def to_int(v, default=0):
    if v is None:
        return default
    if isinstance(v, str):
        vs = v.strip().lower()
        if vs in ["", "nan", "none", "null"]:
            return default
        return int(float(vs))
    return int(v)


def to_nhwc(arr, nframes):
    arr = np.asarray(arr)
    if arr.ndim == 4:
        if arr.shape[0] == nframes:
            nhwc = arr
        elif arr.shape[-1] == nframes:
            nhwc = np.transpose(arr, (3, 0, 1, 2))
        elif arr.shape[2] == nframes:
            nhwc = np.transpose(arr, (2, 0, 1, 3))
        elif arr.shape[0] in (1, 3, 4) and arr.shape[-1] == nframes:
            nhwc = np.transpose(arr, (3, 1, 2, 0))
        else:
            nhwc = np.transpose(arr, (3, 0, 1, 2))
        return nhwc
    if arr.ndim == 3:
        if arr.shape[0] == nframes:
            nhw = arr
        elif arr.shape[-1] == nframes:
            nhw = np.transpose(arr, (2, 0, 1))
        elif arr.shape[2] in (1, 3, 4):
            return arr[np.newaxis, ...]
        else:
            nhw = np.transpose(arr, (2, 0, 1))
        return nhw[..., np.newaxis]
    if arr.ndim == 2:
        return arr[np.newaxis, ..., np.newaxis]
    raise ValueError(f"Unsupported gfp ndim={arr.ndim}, shape={arr.shape}")


def get_model(model_path, gpu):
    global MODEL, MODEL_PATH, MODEL_GPU
    if MODEL is None or MODEL_PATH != model_path or MODEL_GPU != gpu:
        MODEL = models.CellposeModel(gpu=gpu, pretrained_model=model_path)
        MODEL_PATH = model_path
        MODEL_GPU = gpu
        print(f"[PY] Loaded CellposeSAM model: {model_path} | gpu={gpu}")
    else:
        print(f"[PY] Reusing CellposeSAM model: {model_path} | gpu={gpu}")
    return MODEL


def run(cfg_path=None):
    try:
        this_file = __file__
    except Exception:
        this_file = "<exec>"
    print("[PY] runner file:", this_file, flush=True)
    print("[PY] cfg_path:", cfg_path, flush=True)
    try:
        cfg = load_config(cfg_path)
        tmp_mat_path = cfg["tmp_mat_path"]
        classif_path = cfg["classif_path"]
        model_path = cfg.get("model_path", "sam")
    except Exception:
        tb = traceback.format_exc()
        try:
            with open("runner_error.txt", "w", encoding="utf-8") as f:
                f.write(tb)
        except Exception:
            pass
        raise
    gpu = bool(cfg.get("gpu", False))
    if gpu and not torch.cuda.is_available():
        print("[WARN] GPU requested but not available. Falling back to CPU.")
        gpu = False
    diameter = to_float(cfg.get("diameter", None), None)
    flow_threshold = to_float(cfg.get("flow_threshold", 0.4), 0.4)
    cell_prob_threshold = to_float(cfg.get("cell_prob_threshold", 0.0), 0.0)
    min_size = to_int(cfg.get("min_size", 10), 10)
    mode = cfg.get("mode", "segmentation")

    print("torch.cuda.is_available():", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("GPU utilise :", torch.cuda.get_device_name(0))

    if not os.path.exists(tmp_mat_path):
        raise RuntimeError(f"tmp_mat_path not found: {tmp_mat_path}")
    if not os.path.exists(classif_path):
        raise RuntimeError(f"classif_path not found: {classif_path}")

    stamp_path = os.path.join(classif_path, "runner_stamp.txt")
    try:
        with open(stamp_path, "w", encoding="utf-8") as f:
            f.write(f"cfg_path={cfg_path}\n")
            f.write(f"tmp_mat_path={tmp_mat_path}\n")
            f.write(f"classif_path={classif_path}\n")
    except Exception:
        pass

    try:
        mat_data = sio.loadmat(tmp_mat_path)
        if "gfp" not in mat_data or "frames" not in mat_data:
            raise RuntimeError(f"tmp.mat missing keys: {list(mat_data.keys())}")
        gfp = mat_data["gfp"]
        frames_list = mat_data["frames"].flatten().astype(int)
    except Exception:
        tb = traceback.format_exc()
        try:
            with open(os.path.join(classif_path, "runner_error.txt"), "w", encoding="utf-8") as f:
                f.write(tb)
        except Exception:
            pass
        raise

    if len(frames_list) == 0:
        raise RuntimeError("frames_list empty in tmp.mat; nothing to segment.")

    raw_shape = np.asarray(gfp).shape
    print("gfp shape (raw):", raw_shape, flush=True)
    gfp_reord = to_nhwc(gfp, len(frames_list))
    print("gfp shape (NHWC):", gfp_reord.shape, flush=True)
    if gfp_reord.shape[-1] == 1:
        gfp_reord = np.repeat(gfp_reord, 3, axis=-1)

    if gfp_reord.shape[0] != len(frames_list):
        n = min(gfp_reord.shape[0], len(frames_list))
        print(f"[WARN] frame count mismatch: gfp={gfp_reord.shape[0]} vs frames={len(frames_list)}. Truncating to {n}.")
        gfp_reord = gfp_reord[:n]
        frames_list = frames_list[:n]

    images = [img.astype(np.uint8) for img in gfp_reord]
    if len(images) == 0:
        raise RuntimeError("No images generated from gfp; check gfp shape and frames_list.")

    print("Mode =", mode, flush=True)
    model = get_model(model_path, gpu)
    print("Modele charge depuis :", model_path, flush=True)

    H, W = images[0].shape[:2]
    masks_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.uint16)
    cellprob_all = None
    if mode == "proba":
        cellprob_all = np.zeros((H, W, 1, len(frames_list)), dtype=np.float32)

    for i, (img, frame_idx) in enumerate(zip(images, frames_list)):
        try:
            masks, flows, styles = model.eval(
                img,
                diameter=diameter,
                channels=[0, 0],
                flow_threshold=flow_threshold,
                cellprob_threshold=cell_prob_threshold,
                min_size=min_size,
            )
        except Exception:
            tb = traceback.format_exc()
            try:
                with open(os.path.join(classif_path, "runner_error.txt"), "w", encoding="utf-8") as f:
                    f.write(tb)
                    f.write(f"\nframe_index={i} frame_id={frame_idx} img_shape={getattr(img,'shape',None)}\n")
            except Exception:
                pass
            raise
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

    results_path = os.path.join(classif_path, "results.mat")
    try:
        sio.savemat(results_path, out)
        print("CellposeSAM termine. Champs sauvegardes:", list(out.keys()), flush=True)
    except Exception:
        tb = traceback.format_exc()
        try:
            with open(os.path.join(classif_path, "runner_error.txt"), "w", encoding="utf-8") as f:
                f.write(tb)
        except Exception:
            pass
        raise
    try:
        results_bytes = os.path.getsize(results_path)
        results_mtime = os.path.getmtime(results_path)
    except Exception:
        results_bytes = -1
        results_mtime = -1

    return {
        "frames_len": int(len(frames_list)),
        "frames_min": int(frames_list.min()) if len(frames_list) else -1,
        "frames_max": int(frames_list.max()) if len(frames_list) else -1,
        "gfp_shape": tuple(int(x) for x in raw_shape),
        "results_path": results_path,
        "results_bytes": int(results_bytes),
        "results_mtime": float(results_mtime),
        "model_path": str(model_path),
        "gpu": bool(gpu),
    }


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


if __name__ == "__main__":
    run()
