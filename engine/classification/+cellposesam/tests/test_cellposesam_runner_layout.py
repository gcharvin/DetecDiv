"""Regression tests for CellposeSAM input layout normalization."""

import importlib.util
import builtins
import os
from pathlib import Path
import tempfile
import unittest

import numpy as np


RUNNER_PATH = Path(
    os.environ.get(
        "DETECDIV_CELLPOSERUNNER_PATH",
        Path(__file__).parents[1] / "py" / "cellposesam_runner.py",
    )
)
SPEC = importlib.util.spec_from_file_location("cellposesam_runner_layout_test", RUNNER_PATH)
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class TestToNhwc(unittest.TestCase):
    def test_log_tee_is_resolvable_as_a_module_level_function(self):
        original_print = builtins.print
        try:
            with tempfile.TemporaryDirectory() as tmp_dir:
                log_path = Path(tmp_dir) / "runner.log"
                RUNNER.install_log_tee(str(log_path))

                self.assertIs(builtins.print, RUNNER.tee_print)
                self.assertEqual(RUNNER.tee_print.__module__, RUNNER.__name__)
                builtins.print("tee regression check", flush=True)
                self.assertIn("tee regression check", log_path.read_text(encoding="utf-8"))
                RUNNER.TEE_LOG_HANDLE.close()
                RUNNER.TEE_LOG_HANDLE = None
                RUNNER.TEE_LOG_PATH = None
        finally:
            builtins.print = original_print
            if RUNNER.TEE_LOG_HANDLE is not None:
                RUNNER.TEE_LOG_HANDLE.close()
            RUNNER.TEE_LOG_HANDLE = None
            RUNNER.TEE_LOG_PATH = None

    def test_matlab_hwct_wins_when_height_equals_frame_count(self):
        raw = np.arange(60 * 60 * 1 * 60, dtype=np.uint16).reshape(60, 60, 1, 60)

        actual = RUNNER.to_nhwc(raw, 60)

        self.assertEqual(actual.shape, (60, 60, 60, 1))
        np.testing.assert_array_equal(actual[17, :, :, 0], raw[:, :, 0, 17])

    def test_general_matlab_hwct(self):
        raw = np.zeros((32, 48, 3, 10), dtype=np.uint8)

        actual = RUNNER.to_nhwc(raw, 10)

        self.assertEqual(actual.shape, (10, 32, 48, 3))

    def test_existing_nhwc_is_unchanged(self):
        raw = np.zeros((10, 32, 48, 1), dtype=np.uint8)

        actual = RUNNER.to_nhwc(raw, 10)

        self.assertIs(actual, raw)

    def test_nchw_is_supported(self):
        raw = np.zeros((10, 1, 32, 48), dtype=np.uint8)

        actual = RUNNER.to_nhwc(raw, 10)

        self.assertEqual(actual.shape, (10, 32, 48, 1))


if __name__ == "__main__":
    unittest.main()
