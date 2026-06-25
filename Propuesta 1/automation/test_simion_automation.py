import json
import tempfile
import unittest
from pathlib import Path

from simion_automation import (
    calculate_metrics,
    parse_adjustables,
    parse_detector_summary,
    parse_report,
    validate_candidate,
)


ROOT = Path(__file__).resolve().parents[1]


class ReportTests(unittest.TestCase):
    def test_current_report(self):
        run = parse_report(ROOT / "Resultados" / "transmision.csv")
        metrics = calculate_metrics(run)
        self.assertEqual(run.ions_flown, 100)
        self.assertEqual(metrics["ions_detected"], 31)
        self.assertAlmostEqual(metrics["transmission"], 0.31)
        self.assertAlmostEqual(metrics["centroid_y_mm"], 75.76959032258065)

    def test_zero_detection_is_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "empty.csv"
            report.write_text("Begin Fly'm\nNumber of Ions to Fly = 100\n")
            run = parse_report(report)
            metrics = calculate_metrics(run)
            self.assertEqual(metrics["ions_detected"], 0)
            self.assertEqual(metrics["transmission"], 0.0)

    def test_detector_summary(self):
        metrics = parse_detector_summary(
            "DETECT_SUMMARY launched=100 crossings_from_right=31 in_aperture=30 "
            "valid=24 transmission=0.24 theta_max_deg=5 mean_theta_deg=3.1 "
            "theta_le_1=2 theta_le_2=8 theta_le_5=24 theta_le_10=29 "
            "theta_le_15=31 x_mm=455.656248 y_mm=75 z_mm=380.620416 radius_mm=0"
        )
        self.assertIsNotNone(metrics)
        assert metrics is not None
        self.assertEqual(metrics["ions_detected"], 24)
        self.assertEqual(metrics["ions_crossing_from_right"], 31)
        self.assertAlmostEqual(metrics["transmission"], 0.24)
        self.assertEqual(metrics["detector_direction"], "reference_exit_to_detector")


class GuardrailTests(unittest.TestCase):
    def setUp(self):
        self.config = {
            "current_voltages": [0.0] * 41,
            "bounds": [[-100.0, 100.0] for _ in range(41)],
            "max_step": 10.0,
            "fixed_electrodes": {"1": 0.0},
        }

    def test_accepts_safe_candidate(self):
        self.assertEqual(validate_candidate([0.0] * 41, self.config), [0.0] * 41)

    def test_rejects_large_step(self):
        candidate = [0.0] * 41
        candidate[1] = 11.0
        with self.assertRaisesRegex(ValueError, "supera máximo"):
            validate_candidate(candidate, self.config)


    def test_parse_adjustables(self):
        self.assertEqual(
            parse_adjustables(["group_c_only=1", "V3=-12.5"]),
            {"group_c_only": 1.0, "V3": -12.5},
        )


if __name__ == "__main__":
    unittest.main()
