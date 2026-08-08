from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import numpy as np


MODULE_PATH = Path(__file__).resolve().parents[1] / "classify_sam31.py"
SPEC = importlib.util.spec_from_file_location("classify_sam31_under_test", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
CLASSIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CLASSIFY)


class ProviderTrackCandidatesTest(unittest.TestCase):
    def test_follows_geometry_when_provider_label_changes(self) -> None:
        labels = np.zeros((24, 24, 4), dtype=np.uint16)
        labels[8:13, 8:13, 0] = 7
        labels[8:13, 9:14, 1] = 7
        labels[9:14, 10:15, 2] = 12
        labels[10:15, 11:16, 3] = 12
        labels[1:5, 17:21, :] = 99
        seed = labels[:, :, 0] == 7

        masks, stats = CLASSIFY.provider_track_candidates(labels, seed)

        self.assertIsNotNone(masks)
        assert masks is not None
        self.assertEqual(stats["selected_labels"], [7, 7, 12, 12])
        self.assertTrue(np.array_equal(masks[:, :, 2] > 0, labels[:, :, 2] == 12))

    def test_bridges_one_missing_provider_frame(self) -> None:
        labels = np.zeros((24, 24, 4), dtype=np.uint16)
        labels[8:13, 8:13, 0] = 4
        labels[9:14, 9:14, 2] = 18
        labels[10:15, 10:15, 3] = 18
        seed = labels[:, :, 0] == 4

        masks, stats = CLASSIFY.provider_track_candidates(labels, seed, max_gap=1)

        self.assertIsNotNone(masks)
        assert masks is not None
        self.assertEqual(stats["selected_labels"], [4, 0, 18, 18])
        self.assertEqual(int(masks[:, :, 1].sum()), 0)
        self.assertGreater(int(masks[:, :, 2].sum()), 0)

    def test_rejects_provider_without_seed_overlap(self) -> None:
        labels = np.zeros((16, 16, 3), dtype=np.uint16)
        labels[1:4, 1:4, :] = 3
        seed = np.zeros((16, 16), dtype=bool)
        seed[10:13, 10:13] = True

        masks, stats = CLASSIFY.provider_track_candidates(labels, seed)

        self.assertIsNone(masks)
        self.assertEqual(stats["reason"], "no_provider_object_overlaps_seed")


if __name__ == "__main__":
    unittest.main()
