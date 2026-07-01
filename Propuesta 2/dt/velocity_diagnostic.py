from __future__ import annotations

import argparse
import csv
import math
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.generate_dataset import full_voltage_vector  # noqa: E402


VOLTAGE_NAMES = ["V3", "V6", "V9", "V10", "V11", "V12", "V15", "V18"]
DEFAULT_SOURCES = [
    ROOT / "dt" / "data" / "inverse_sweep_low_feed_v2" / "summary.csv",
    ROOT / "dt" / "data" / "inverse_sweep_low_feed_v1" / "summary.csv",
    ROOT / "dt" / "data" / "inverse_sweep_dense_v1" / "summary.csv",
    ROOT / "dt" / "data" / "inverse_validation.csv",
]


def load_json(path: Path) -> dict[str, Any]:
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def row_float(row: dict[str, str], key: str, default: float = float("nan")) -> float:
    try:
        return float(row.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def read_candidates(paths: list[Path]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in paths:
        if not path.is_file():
            continue
        with path.open("r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not all(name in row and row[name] not in ("", None) for name in VOLTAGE_NAMES):
                    continue
                item: dict[str, Any] = {
                    "source": str(path.relative_to(ROOT)),
                    "case": row.get("case", path.stem),
                    "rank": row.get("rank", ""),
                    "hint_active": row_float(row, "sim_active", row_float(row, "detector_active_contact_fraction")),
                    "hint_theta_mean": row_float(row, "sim_theta_mean", row_float(row, "detector_contact_angle_theta_mean_deg")),
                    "hint_theta_sigma": row_float(row, "sim_theta_sigma", row_float(row, "detector_contact_angle_theta_sigma_deg")),
                }
                for name in VOLTAGE_NAMES:
                    item[name] = row_float(row, name)
                rows.append(item)
    return rows


def diverse_by_angle(rows: list[dict[str, Any]], limit: int) -> list[dict[str, Any]]:
    usable = [r for r in rows if math.isfinite(float(r.get("hint_theta_mean", float("nan"))))]
    if not usable:
        return rows[:limit]
    usable.sort(key=lambda r: float(r["hint_theta_mean"]))
    if len(usable) <= limit:
        return usable
    selected = []
    seen = set()
    for i in range(limit):
        idx = round(i * (len(usable) - 1) / max(1, limit - 1))
        row = usable[idx]
        key = tuple(round(float(row[name]), 3) for name in VOLTAGE_NAMES)
        if key not in seen:
            seen.add(key)
            selected.append(row)
    j = 0
    while len(selected) < limit and j < len(usable):
        row = usable[j]
        key = tuple(round(float(row[name]), 3) for name in VOLTAGE_NAMES)
        if key not in seen:
            seen.add(key)
            selected.append(row)
        j += 1
    return selected


def estimate_from_angles(speed: float, theta_mean_deg: float, theta_sigma_deg: float) -> dict[str, float]:
    theta = math.radians(theta_mean_deg)
    sigma = math.radians(theta_sigma_deg)
    # Aproximaciones simples. La sigma es una regla local; no pretende capturar
    # asimetría/multimodalidad de la distribución angular.
    cos_mean_normal = math.cos(theta) * math.exp(-0.5 * sigma * sigma)
    cos2_mean_normal = 0.5 * (1.0 + math.cos(2.0 * theta) * math.exp(-2.0 * sigma * sigma))
    vz_sigma_normal = speed * math.sqrt(max(0.0, cos2_mean_normal - cos_mean_normal * cos_mean_normal))
    return {
        "est_vperp_mean_from_theta_mean": speed * math.sin(theta),
        "est_vz_mean_from_theta_mean": speed * math.cos(theta),
        "est_vz_mean_from_theta_normal": speed * cos_mean_normal,
        "est_vperp_sigma_from_theta_sigma_sin": speed * math.sin(sigma),
        "est_vperp_sigma_from_theta_sigma_linear": speed * sigma,
        "est_vz_sigma_delta_method": abs(speed * math.sin(theta) * sigma),
        "est_vz_sigma_normal_theta": vz_sigma_normal,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compara velocidades reales SIMION vs estimadas desde rapidez total y ángulos."
    )
    parser.add_argument("--simion-config", type=Path, default=ROOT / "optuna_config_hackathon_detector_window_quality_v17.json")
    parser.add_argument("--dt-config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--source", type=Path, action="append", default=[])
    parser.add_argument("--limit", type=int, default=16)
    parser.add_argument("--out", type=Path, default=ROOT / "dt" / "data" / "velocity_diagnostic.csv")
    args = parser.parse_args()

    sources = [p.resolve() for p in args.source] if args.source else DEFAULT_SOURCES
    candidates = diverse_by_angle(read_candidates(sources), args.limit)
    if not candidates:
        raise FileNotFoundError("No encontré candidatos con voltajes para diagnosticar.")

    simion_cfg = load_config(args.simion_config.resolve())
    dt_cfg = load_json(args.dt_config.resolve())
    out_rows: list[dict[str, Any]] = []
    for i, cand in enumerate(candidates, start=1):
        free = {name: float(cand[name]) for name in VOLTAGE_NAMES}
        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        active = float(metrics.get("detector_active_contact_fraction") or 0.0)
        theta_mean = float(metrics.get("detector_contact_angle_theta_mean_deg") or 0.0)
        theta_sigma = float(metrics.get("detector_contact_angle_theta_sigma_deg") or 0.0)
        speed_mean = float(metrics.get("detector_contact_speed_speed_mean") or 0.0)
        estimates = estimate_from_angles(speed_mean, theta_mean, theta_sigma)
        row: dict[str, Any] = {
            "i": i,
            "source": cand.get("source"),
            "case": cand.get("case"),
            "rank": cand.get("rank"),
            "elapsed_seconds": metadata.get("elapsed_seconds"),
            **free,
            "active": active,
            "theta_mean_deg": theta_mean,
            "theta_sigma_deg": theta_sigma,
            "speed_count": metrics.get("detector_contact_speed_count", 0),
            "speed_mean": speed_mean,
            "speed_sigma": metrics.get("detector_contact_speed_speed_sigma", 0.0),
            "speed_rel_sigma": metrics.get("detector_contact_speed_speed_rel_sigma", 0.0),
            "vperp_mean": metrics.get("detector_contact_speed_vperp_mean", 0.0),
            "vperp_sigma": metrics.get("detector_contact_speed_vperp_sigma", 0.0),
            "vperp_rel_sigma": metrics.get("detector_contact_speed_vperp_rel_sigma", 0.0),
            "vz_mean": metrics.get("detector_contact_speed_vz_mean", 0.0),
            "vz_sigma": metrics.get("detector_contact_speed_vz_sigma", 0.0),
            "vz_rel_sigma": metrics.get("detector_contact_speed_vz_rel_sigma", 0.0),
            **estimates,
        }
        row["err_vperp_mean_est"] = float(row["vperp_mean"]) - row["est_vperp_mean_from_theta_mean"]
        row["err_vperp_sigma_est_sin"] = float(row["vperp_sigma"]) - row["est_vperp_sigma_from_theta_sigma_sin"]
        row["err_vperp_sigma_est_linear"] = float(row["vperp_sigma"]) - row["est_vperp_sigma_from_theta_sigma_linear"]
        row["err_vz_mean_est"] = float(row["vz_mean"]) - row["est_vz_mean_from_theta_mean"]
        row["err_vz_sigma_est"] = float(row["vz_sigma"]) - row["est_vz_sigma_delta_method"]
        row["err_vz_mean_normal_est"] = float(row["vz_mean"]) - row["est_vz_mean_from_theta_normal"]
        row["err_vz_sigma_normal_est"] = float(row["vz_sigma"]) - row["est_vz_sigma_normal_theta"]
        out_rows.append(row)
        print(
            f"{i:02d}/{len(candidates)} active={100*active:5.1f}% "
            f"theta={theta_mean:6.2f}±{theta_sigma:5.2f}° "
            f"speed_rel={100*float(row['speed_rel_sigma']):.3f}% "
            f"vperp real/est={float(row['vperp_mean']):.3f}/{row['est_vperp_mean_from_theta_mean']:.3f} "
            f"sig real/est={float(row['vperp_sigma']):.3f}/{row['est_vperp_sigma_from_theta_sigma_linear']:.3f}"
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(out_rows[0].keys()))
        writer.writeheader()
        writer.writerows(out_rows)
    print(f"CSV: {args.out}")

    def mae(key: str) -> float:
        return sum(abs(float(r[key])) for r in out_rows) / len(out_rows)

    print(
        "MAE "
        f"vperp_mean={mae('err_vperp_mean_est'):.4g} "
        f"vperp_sigma_linear={mae('err_vperp_sigma_est_linear'):.4g} "
        f"vz_mean={mae('err_vz_mean_est'):.4g} "
        f"vz_sigma={mae('err_vz_sigma_est'):.4g} "
        f"vz_sigma_normal={mae('err_vz_sigma_normal_est'):.4g}"
    )


if __name__ == "__main__":
    main()
