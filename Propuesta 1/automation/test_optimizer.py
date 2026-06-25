import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import optimize_voltages as optimizer


class FakeObjective:
    def measure(self, voltages, repeats):
        transmission = 1.0 - 0.1 * abs(float(voltages["V2"]) - 2.0)
        return optimizer.Measurement(dict(voltages), (transmission,) * repeats, 0.0)


class OptimizerTests(unittest.TestCase):
    def test_converges_and_checkpoints_without_fixed_budget(self):
        config = {
            "electrodes": [
                {"name": "V2", "initial": 0, "min": -4, "max": 4, "step": 2, "min_step": 1, "max_step": 2},
                {"name": "V3", "initial": 0, "min": 0, "max": 0, "step": 1, "min_step": 1, "max_step": 1},
                {"name": "V8", "initial": 0, "min": 0, "max": 0, "step": 1, "min_step": 1, "max_step": 1},
                {"name": "V14", "initial": 0, "min": 0, "max": 0, "step": 1, "min_step": 1, "max_step": 1},
            ],
            "repeats_per_candidate": 1,
            "final_repeats": 1,
            "minimum_improvement": 0.01,
            "patience_rounds": 2,
            "step_growth": 1.5,
            "global_search": {
                "batch_size": 4,
                "repeats_per_candidate": 1,
                "minimum_batches": 1,
                "patience_batches": 1,
                "minimum_improvement": 0.01,
                "elite_count": 2,
                "elite_total_repeats": 1,
                "seed": 7,
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "checkpoint.json"
            with patch.object(optimizer, "SimionObjective", FakeObjective):
                result = optimizer.optimize(config, checkpoint, resume=False)
            self.assertEqual(result["status"], "converged")
            self.assertGreater(result["best_search"]["mean_transmission"], 0.9)
            self.assertTrue(checkpoint.is_file())
            self.assertEqual(json.loads(checkpoint.read_text())["status"], "converged")


if __name__ == "__main__":
    unittest.main()
