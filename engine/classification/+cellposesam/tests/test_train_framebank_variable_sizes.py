"""End-to-end tests for variable-size CellposeSAM framebanks."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

import h5py
import numpy as np


TRAIN_PATH = Path(__file__).parents[1] / "py" / "train_cellposesam.py"
SPEC = importlib.util.spec_from_file_location("train_cellposesam_framebank_test", TRAIN_PATH)
TRAIN_MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRAIN_MODULE)


class TestVariableSizeFramebank(unittest.TestCase):
    def test_loader_removes_centered_padding_for_each_roi(self):
        native_shapes = [(60, 59), (137, 66)]
        max_h = max(shape[0] for shape in native_shapes)
        max_w = max(shape[1] for shape in native_shapes)

        images = np.zeros((2, 1, max_w, max_h), dtype=np.uint8)
        masks = np.zeros((2, max_w, max_h), dtype=np.uint16)
        original_size = np.asarray(native_shapes, dtype=np.int32)
        pad_offset = np.zeros((2, 2), dtype=np.int32)
        expected_images = []
        expected_masks = []

        for idx, (height, width) in enumerate(native_shapes):
            top = (max_h - height) // 2
            left = (max_w - width) // 2
            pad_offset[idx] = (top, left)

            native_image = (
                np.arange(height * width, dtype=np.uint32).reshape(height, width) + idx
            ).astype(np.uint8)
            native_mask = np.zeros((height, width), dtype=np.uint16)
            native_mask[height // 4 : height // 2, width // 4 : width // 2] = idx + 1

            padded_image = np.zeros((max_h, max_w), dtype=np.uint8)
            padded_mask = np.zeros((max_h, max_w), dtype=np.uint16)
            padded_image[top : top + height, left : left + width] = native_image
            padded_mask[top : top + height, left : left + width] = native_mask

            # Raw h5py layout produced by MATLAB [H W C N] and [H W N].
            images[idx, 0] = padded_image.T
            masks[idx] = padded_mask.T
            expected_images.append(native_image)
            expected_masks.append(native_mask)

        with tempfile.TemporaryDirectory() as tmp_dir:
            framebank = Path(tmp_dir) / "variable_framebank.h5"
            with h5py.File(framebank, "w") as handle:
                handle.create_dataset("images", data=images)
                handle.create_dataset("masks", data=masks)
                handle.create_dataset("split", data=np.asarray([[1, 2]], dtype=np.uint8))
                handle.create_dataset("roi_id", data=np.asarray([[1, 2]], dtype=np.int32))
                handle.create_dataset("frame_idx", data=np.asarray([[1, 1]], dtype=np.int32))
                handle.create_dataset("original_size", data=original_size)
                handle.create_dataset("pad_offset", data=pad_offset)

            train_images, train_labels, val_images, val_labels = (
                TRAIN_MODULE.load_from_framebank(str(framebank), seed=7)
            )

        self.assertEqual(train_images[0].shape, native_shapes[0])
        self.assertEqual(val_images[0].shape, native_shapes[1])
        np.testing.assert_array_equal(train_images[0], expected_images[0])
        np.testing.assert_array_equal(train_labels[0], expected_masks[0])
        np.testing.assert_array_equal(val_images[0], expected_images[1])
        np.testing.assert_array_equal(val_labels[0], expected_masks[1])


if __name__ == "__main__":
    unittest.main()
