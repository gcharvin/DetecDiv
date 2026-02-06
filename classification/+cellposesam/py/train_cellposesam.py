import os
import json
import random
import datetime
import numpy as np
import h5py
import torch
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from cellpose import io, train, models


def load_config():
    cfg_path = os.environ.get("CPSAM_CONFIG", "")
    if not cfg_path:
        raise RuntimeError("CPSAM_CONFIG env var not set.")
    with open(cfg_path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_from_framebank(framebank_path, seed=None):
    # Load images/masks from framebank and use /split (0=test,1=train,2=val)
    if not os.path.exists(framebank_path):
        raise FileNotFoundError(f"Framebank not found: {framebank_path}")

    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(framebank_path))
    print("[INFO] loading framebank:", framebank_path)
    print("[INFO] framebank last modified:", mtime.isoformat())

    with h5py.File(framebank_path, "r") as f:
        images = f["/images"]  # MATLAB: [H W C N] -> Python (legacy layout)
        masks = f["/masks"]    # MATLAB: [H W N]
        split_raw = f["/split"][:]
        split = np.array(split_raw, dtype=np.uint8).ravel()

        print("[DEBUG] images shape (raw):", images.shape)
        print("[DEBUG] masks shape (raw):", masks.shape)
        print("[DEBUG] split shape (raw):", split_raw.shape, "->", split.shape)

        N_img = images.shape[0]
        N_msk = masks.shape[0]
        N_split = split.size

        if not (N_img == N_msk == N_split):
            raise RuntimeError(
                f"Inconsistent N between images/masks/split: "
                f"images={images.shape}, masks={masks.shape}, split_len={N_split}"
            )

        train_idx = np.where(split == 1)[0]
        val_idx = np.where(split == 2)[0]
        test_idx = np.where(split == 0)[0]

        print(f"[INFO] split: {len(train_idx)} train, {len(val_idx)} val, {len(test_idx)} test frames")

        if len(train_idx) == 0:
            raise RuntimeError("No frames with split==1 (train) found in framebank.")

        train_idx = np.sort(train_idx)
        val_idx = np.sort(val_idx)

        imgs = []
        labels = []
        val_imgs = []
        val_labels = []
        masks_per_img = []
        pixels_per_img = []

        # helper to convert image/mask
        def _process_one(idx):
            lab = np.array(masks[idx])  # (W, H)
            lab = lab.T  # (H, W)
            if lab.ndim != 2:
                raise RuntimeError(f"Loaded mask with ndim={lab.ndim}, expected 2")

            img = np.array(images[idx])  # (C, W, H) or (W, H)
            if img.ndim == 3:
                img = np.transpose(img, (2, 1, 0))  # (H, W, C)
                if img.shape[2] == 1:
                    img = img[:, :, 0]  # (H, W)
            elif img.ndim == 2:
                img = img.T  # (H, W)
            else:
                raise RuntimeError(
                    f"Loaded image with unexpected ndim={img.ndim}, shape={img.shape}"
                )
            return img, lab

        for idx in train_idx:
            img, lab = _process_one(idx)
            n_masks = int(lab.max())
            n_pixels = int((lab > 0).sum())
            masks_per_img.append(n_masks)
            pixels_per_img.append(n_pixels)
            imgs.append(img)
            labels.append(lab)

        for idx in val_idx:
            img, lab = _process_one(idx)
            val_imgs.append(img)
            val_labels.append(lab)

    masks_per_img = np.array(masks_per_img) if len(masks_per_img) > 0 else np.array([0])
    pixels_per_img = np.array(pixels_per_img) if len(pixels_per_img) > 0 else np.array([0])
    print(
        f"[DEBUG] masks_per_img (train): min={masks_per_img.min()}, "
        f"max={masks_per_img.max()}, mean={masks_per_img.mean():.2f}"
    )
    print(
        f"[DEBUG] pixels_per_img (train): min={pixels_per_img.min()}, "
        f"max={pixels_per_img.max()}, mean={pixels_per_img.mean():.1f}"
    )

    if len(imgs) == 0:
        raise RuntimeError("No training images found in framebank (split==1).")
    print("[INFO] first training image shape (after reorder):", imgs[0].shape)
    return imgs, labels, val_imgs, val_labels


def train_model():
    cfg = load_config()

    framebank_path = cfg["framebank_path"]
    save_path = cfg["save_path"]
    model_name = cfg["model_name"]
    seed = int(cfg.get("seed", 12345))
    use_pretrained = bool(cfg.get("use_pretrained", True))
    verbose = bool(cfg.get("verbose", True))
    gpu = bool(cfg.get("gpu", True))
    if gpu and not torch.cuda.is_available():
        print("[WARN] GPU requested but not available. Falling back to CPU.")
        gpu = False

    weight_decay = float(cfg.get("weight_decay", 1e-5))
    learning_rate = float(cfg.get("learning_rate", 1e-4))
    n_epochs = int(cfg.get("n_epochs", 50))
    batch_size = int(cfg.get("batch_size", 1))
    min_train_masks = int(cfg.get("min_train_masks", 0))

    if verbose:
        io.logger_setup()

    os.environ["PYTHONHASHSEED"] = str(seed)
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    imgs, labels, val_imgs, val_labels = load_from_framebank(framebank_path, seed=seed)
    print(f"[INFO] loaded {len(imgs)} train images and {len(val_imgs)} val images FROM framebank")

    device = torch.device("cuda" if gpu and torch.cuda.is_available() else "cpu")
    print(f"[INFO] device: {device}")

    pretrained_model = "sam" if use_pretrained else None

    model = models.CellposeModel(
        gpu=gpu,
        device=device,
        pretrained_model=pretrained_model,
    )

    if len(val_imgs) > 0:
        test_data = val_imgs
        test_labels = val_labels
    else:
        test_data = None
        test_labels = None

    model_path, train_losses, test_losses = train.train_seg(
        model.net,
        train_data=imgs,
        train_labels=labels,
        test_data=test_data,
        test_labels=test_labels,
        weight_decay=weight_decay,
        learning_rate=learning_rate,
        n_epochs=n_epochs,
        model_name=model_name,
        save_path=save_path,
        batch_size=batch_size,
        min_train_masks=min_train_masks,
    )
    print("[INFO] training finished, model saved to", model_path)

    best_epoch = None
    best_metric = None
    metric_name = None

    if test_losses is not None and len(test_losses) > 0:
        best_epoch = int(np.argmin(test_losses))
        best_metric = float(test_losses[best_epoch])
        metric_name = "val_loss"
    elif train_losses is not None and len(train_losses) > 0:
        best_epoch = int(np.argmin(train_losses))
        best_metric = float(train_losses[best_epoch])
        metric_name = "train_loss"

    if best_epoch is not None:
        best_path = os.path.join(save_path, f"{model_name}_best.pth")
        torch.save(model.net.state_dict(), best_path)
        print(f"[INFO] Best model (by {metric_name}) saved at epoch {best_epoch+1} with value {best_metric:.6f}")
        print(f"[INFO] Best model path: {best_path}")
    else:
        print("[WARN] Could not determine best model (no losses).")

    if train_losses is not None and len(train_losses) > 0:
        epochs = np.arange(1, len(train_losses) + 1)
        loss_png = os.path.join(save_path, f"{model_name}_losses.png")
        try:
            plt.figure(figsize=(8, 5))
            plt.plot(epochs, train_losses, label="train loss")
            if test_losses is not None and len(test_losses) == len(train_losses):
                plt.plot(epochs, test_losses, label="test loss")
            plt.xlabel("epoch")
            plt.ylabel("loss")
            plt.title(f"Cellpose training: {model_name}")
            plt.grid(True, linestyle="--", alpha=0.4)
            plt.legend()
            plt.tight_layout()
            plt.savefig(loss_png, dpi=150)
            plt.close()
            print("[INFO] loss plot saved to:", loss_png)
        except Exception as e:
            print("[WARN] could not save loss plot:", e)


if __name__ == "__main__":
    train_model()
