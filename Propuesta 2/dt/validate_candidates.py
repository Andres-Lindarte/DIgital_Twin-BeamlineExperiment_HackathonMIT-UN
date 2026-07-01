from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.derived_metrics import residual_from_row, vz_from_angle_normal  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_candidates(path: Path, voltage_names: list[str], limit: int) -> list[dict[str, Any]]:
    rows = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            item: dict[str, Any] = dict(row)
            item["voltages"] = {name: float(row[name]) for name in voltage_names}
            rows.append(item)
            if len(rows) >= limit:
                break
    return rows


def full_voltage_vector(dt_cfg: dict[str, Any], free_voltages: dict[str, float]) -> dict[str, float]:
    out = {str(k): float(v) for k, v in dt_cfg.get("fixed_voltages", {}).items()}
    out.update({str(k): float(v) for k, v in free_voltages.items()})
    return dict(sorted(out.items(), key=lambda item: int(item[0][1:])))


def metric(metrics: dict[str, Any], key: str, default: float = 0.0) -> float:
    value = metrics.get(key, default)
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main() -> None:
    parser = argparse.ArgumentParser(description="Valida candidatos DT inversos en SIMION/Lua.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--simion-config", type=Path, default=ROOT / "optuna_config_hackathon_detector_window_quality_v17.json")
    parser.add_argument("--candidates", type=Path, default=ROOT / "dt" / "data" / "inverse_candidates.csv")
    parser.add_argument("--top", type=int, default=5)
    parser.add_argument("--out", type=Path, default=ROOT / "dt" / "data" / "inverse_validation.csv")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    candidates = read_candidates(args.candidates.resolve(), voltage_names, args.top)
    simion_cfg = load_config(args.simion_config.resolve())

    rows: list[dict[str, Any]] = []
    for i, cand in enumerate(candidates, start=1):
        free = cand["voltages"]
        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        row: dict[str, Any] = {
            "rank": i,
            "elapsed_seconds": metadata.get("elapsed_seconds"),
            **free,
            "pred_active": cand.get("pred_detector_active_contact_fraction", ""),
            "pred_forward": cand.get("pred_detector_active_forward_fraction", ""),
            "pred_theta_mean": cand.get("pred_detector_contact_angle_theta_mean_deg", ""),
            "pred_theta_sigma": cand.get("pred_detector_contact_angle_theta_sigma_deg", ""),
            "pred_derived_vz_mean": cand.get("derived_vz_mean", ""),
            "pred_derived_vz_sigma_physics": cand.get("derived_vz_sigma_physics", ""),
            "pred_derived_vz_sigma_corrected": cand.get("derived_vz_sigma_corrected", ""),
            "pred_viability_prob": cand.get("pred_viability_prob", ""),
            "unc_viability_prob": cand.get("unc_viability_prob", ""),
            "sim_active": metric(metrics, "detector_active_contact_fraction"),
            "sim_forward": metric(metrics, "detector_active_forward_fraction"),
            "sim_theta_mean": metric(metrics, "detector_contact_angle_theta_mean_deg"),
            "sim_theta_sigma": metric(metrics, "detector_contact_angle_theta_sigma_deg"),
            "sim_theta_p95": metric(metrics, "detector_contact_angle_theta_p95_deg"),
            "sim_speed_mean": metric(metrics, "detector_contact_speed_speed_mean"),
            "sim_vz_mean": metric(metrics, "detector_contact_speed_vz_mean"),
            "sim_vz_sigma": metric(metrics, "detector_contact_speed_vz_sigma"),
            "sim_n_active": int(metric(metrics, "detector_active_contact_count")),
            "sim_n_forward": int(metric(metrics, "detector_contact_angle_forward")),
            "sim_n_backward": int(metric(metrics, "detector_contact_angle_backward")),
            "sim_bpm_score": metric(metrics, "bpm_real_score"),
        }
        sim_derived = vz_from_angle_normal(
            row["sim_theta_mean"],
            row["sim_theta_sigma"],
            row["sim_speed_mean"] or 130.62,
        )
        row["sim_vz_mean_physics"] = sim_derived["derived_vz_mean"]
        row["sim_vz_sigma_physics"] = sim_derived["derived_vz_sigma_physics"]
        row_for_residual = {
            "detector_contact_angle_theta_mean_deg": row["sim_theta_mean"],
            "detector_contact_angle_theta_sigma_deg": row["sim_theta_sigma"],
            "detector_contact_speed_speed_mean": row["sim_speed_mean"],
            "detector_contact_speed_vz_sigma": row["sim_vz_sigma"],
        }
        residual = residual_from_row(row_for_residual)
        row["sim_vz_sigma_residual"] = "" if residual is None else residual
        rows.append(row)
        print(
            f"{i:02d}: active={100*row['sim_active']:.2f}% "
            f"fwd={100*row['sim_forward']:.2f}% "
            f"theta_mu={row['sim_theta_mean']:.3f} "
            f"theta_sig={row['sim_theta_sigma']:.3f} "
            f"theta95={row['sim_theta_p95']:.3f} "
            f"vz_sig={row['sim_vz_sigma']:.4f} "
            f"vz_res={float(row['sim_vz_sigma_residual'] or 0):+.4f} "
            f"n={row['sim_n_active']}/500 "
            f"| pred active={100*float(row['pred_active'] or 0):.2f}% "
            f"theta_sig={float(row['pred_theta_sigma'] or 0):.3f}"
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Validación: {args.out}")


if __name__ == "__main__":
    main()
