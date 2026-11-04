"""Exercise the installed Cellpose epoch loop with a tiny CPU network."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
import torch

SPEC = importlib.util.spec_from_file_location(
    "train_best_checkpoint_test",
    Path(__file__).parents[1] / "py" / "train_cellposesam.py",
)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class TinyNet(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.weight = torch.nn.Parameter(torch.tensor(0.))
        self.diam_labels = torch.nn.Parameter(torch.tensor([1.]))
        self.diam_mean = torch.tensor(1.)
        self.device = torch.device("cpu")
        self.dtype = torch.float32
        self.backbone = "test"

    def forward(self, images):
        return (self.weight.expand(1, 3, 4, 4),)

    def save_model(self, path):
        torch.save(self.state_dict(), path)


class TestBestCheckpoint(unittest.TestCase):
    def run_epochs(self, folder, validation, training=(4., 3., 2., 1.)):
        net = TinyNet()
        original = runner.train.train_seg
        calls = []

        class Optimizer:
            def __init__(self, *args, **kwargs):
                self.param_groups = [{"lr": 0.}]

            def zero_grad(self):
                pass

            def step(self):
                with torch.no_grad():
                    net.weight.add_(1.)

        def process(**kwargs):
            images = [np.zeros((4, 4), np.float32)]
            labels = [np.ones((4, 4), np.uint16)]
            return (images, labels, None, None, np.ones(1), np.ones(1),
                    images if validation is not None else None,
                    labels if validation is not None else None,
                    None, None, np.ones(1), np.ones(1), True)

        def loss(labels, output, device):
            if net.training:
                epoch = int(net.weight.item())
                value = training[epoch]
            else:
                epoch = int(net.weight.item()) - 1
                calls.append(epoch)
                value = validation[epoch]
            return net.weight * 0 + value

        replacements = {
            "_process_train_test": process,
            "_get_batch": lambda *args, **kwargs: ([np.zeros((4, 4))], [np.ones((4, 4))]),
            "random_rotate_and_resize": lambda *args, **kwargs: (
                torch.zeros(1, 1, 4, 4), np.ones((1, 3, 4, 4))),
            "_loss_fn_seg": loss,
        }
        best_path = Path(folder) / "best.pth"
        with patch.dict(original.__globals__, replacements), patch.object(
                torch.optim, "AdamW", Optimizer):
            result = runner.train_with_best_checkpoint(
                net, best_path, n_epochs=len(training), save_path=folder,
                model_name="tiny", test_data=[] if validation is not None else None,
                min_train_masks=0, normalize=False, save_every=2, save_each=True)
        self.assertIs(runner.train.train_seg, original)
        return result, torch.load(best_path, weights_only=True), calls

    def test_best_weights_are_from_middle_epoch_not_final(self):
        with tempfile.TemporaryDirectory() as folder:
            result, best_weights, calls = self.run_epochs(folder, [5., 1., 4., 6.])
            final = torch.load(result[0], weights_only=True)
            self.assertEqual(best_weights["weight"].item(), 2.)
            self.assertEqual(final["weight"].item(), 4.)
            self.assertEqual(result[3], {"epoch": 2, "metric": 1., "metric_name": "val_loss"})
            self.assertEqual(calls, [0, 1, 2, 3])
            np.testing.assert_array_equal(result[2], [5., 1., 4., 6.])

    def test_no_validation_uses_training_loss_and_keeps_first_tie(self):
        with tempfile.TemporaryDirectory() as folder:
            result, weights, calls = self.run_epochs(folder, None, [3., 1., 1., 4.])
            self.assertEqual(result[3]["metric_name"], "train_loss")
            self.assertEqual(result[3]["epoch"], 2)
            self.assertEqual(weights["weight"].item(), 2.)
            self.assertEqual(calls, [])

    def test_real_zero_is_valid_and_nonfinite_losses_are_ignored(self):
        with tempfile.TemporaryDirectory() as folder:
            result, weights, _ = self.run_epochs(folder, [np.nan, 0., np.inf, 2.])
            self.assertEqual(result[3]["metric"], 0.)
            self.assertEqual(weights["weight"].item(), 2.)

    def test_no_finite_validation_does_not_claim_a_best_model(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(RuntimeError, "No finite epoch loss"):
                self.run_epochs(folder, [np.nan] * 4)
            self.assertFalse((Path(folder) / "best.pth").exists())

    def test_incompatible_cellpose_loop_fails_before_training(self):
        def incompatible(net, **kwargs):
            raise AssertionError("must not train")

        with patch.object(runner.train, "train_seg", incompatible):
            with self.assertRaisesRegex(RuntimeError, "Unsupported Cellpose"):
                runner.train_with_best_checkpoint(TinyNet(), "unused.pth")


if __name__ == "__main__":
    unittest.main()
