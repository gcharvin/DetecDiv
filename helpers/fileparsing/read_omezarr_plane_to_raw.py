import json
import sys

import numpy as np
import zarr


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: read_omezarr_plane_to_raw.py config.json", file=sys.stderr)
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        cfg = json.load(fh)

    arr = zarr.open(cfg["array_dir"], mode="r")
    coord = [int(v) for v in cfg["coord"]]
    coord[int(cfg["y_dim"])] = slice(None)
    coord[int(cfg["x_dim"])] = slice(None)

    plane = np.ascontiguousarray(arr[tuple(coord)])
    with open(cfg["out_path"], "wb") as fh:
        fh.write(plane.tobytes(order="C"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
