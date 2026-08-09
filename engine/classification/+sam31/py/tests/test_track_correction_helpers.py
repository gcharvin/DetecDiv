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

    def test_does_not_jump_to_distant_object_from_tiny_dilated_contact(self) -> None:
        labels = np.zeros((60, 59, 4), dtype=np.uint16)
        labels[8:22, 8:18, 0] = 15
        labels[27:46, 23:38, 1:] = 1
        seed = labels[:, :, 0] == 15

        masks, stats = CLASSIFY.provider_track_candidates(labels, seed, max_gap=2)

        self.assertIsNone(masks)
        self.assertEqual(stats["reason"], "provider_has_no_following_candidate")


class LocalMaskTranslationTest(unittest.TestCase):
    def test_reports_mask_distance_from_border(self) -> None:
        mask = np.zeros((20, 30), dtype=bool)
        mask[5:12, 3:9] = True
        self.assertEqual(CLASSIFY.mask_edge_distance(mask), 3)

    def test_recovers_known_one_frame_translation(self) -> None:
        previous = np.zeros((32, 32), dtype=np.float32)
        previous[12:18, 13:19] = np.array(
            [
                [0, 1, 2, 3, 2, 1],
                [1, 3, 6, 7, 4, 2],
                [2, 6, 9, 8, 5, 2],
                [1, 5, 8, 7, 4, 1],
                [0, 2, 4, 4, 2, 0],
                [0, 0, 1, 1, 0, 0],
            ],
            dtype=np.float32,
        )
        current = np.zeros_like(previous)
        current[14:20, 12:18] = previous[12:18, 13:19]
        mask = np.zeros_like(previous, dtype=bool)
        mask[13:18, 14:19] = True

        translated, stats = CLASSIFY.translate_mask_by_local_registration(
            mask, previous, current, search_radius=4, context_margin=2
        )

        expected = np.zeros_like(mask)
        expected[15:20, 13:18] = True
        self.assertTrue(np.array_equal(translated, expected))
        self.assertEqual(stats["shift_xy"], [-1, 2])


class TextTrackCandidateTest(unittest.TestCase):
    def test_rejects_large_detection_that_only_partly_overlaps_seed(self) -> None:
        labels = []
        for _ in range(3):
            frame = np.zeros((30, 30), dtype=np.uint16)
            frame[8:22, 8:22] = 1
            labels.append(frame)
        seed = np.zeros((30, 30), dtype=bool)
        seed[16:21, 16:21] = True
        original = CLASSIFY.run_sam31_text_movie
        CLASSIFY.run_sam31_text_movie = lambda **_kwargs: (labels, [{}, {}, {}])
        try:
            masks, stats = CLASSIFY.text_track_candidates(
                predictor=None,
                image_dir=Path("unused"),
                num_frames=3,
                seed_mask=seed,
                min_score=0.0,
                fallback_shape=(30, 30),
                cancel_path=None,
            )
        finally:
            CLASSIFY.run_sam31_text_movie = original

        self.assertIsNone(masks)
        self.assertEqual(stats["reason"], "text_seed_area_mismatch")


if __name__ == "__main__":
    unittest.main()
