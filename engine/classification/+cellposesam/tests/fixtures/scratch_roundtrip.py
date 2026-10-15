"""Exercise the same JSON/MAT exchange as inference without loading a model."""
import json
import os
import sys

import numpy as np
from scipy.io import loadmat, savemat

with open(sys.argv[1], encoding="utf-8") as stream:
    cfg = json.load(stream)
inputs = loadmat(cfg["tmp_mat_path"])
assert inputs["gfp"].shape == (4, 4, 1, 3)
assert inputs["frames"].ravel().tolist() == [1, 2, 3]
savemat(os.path.join(cfg["classif_path"], "results.mat"),
        {"masks": inputs["gfp"].astype(np.uint16)})
