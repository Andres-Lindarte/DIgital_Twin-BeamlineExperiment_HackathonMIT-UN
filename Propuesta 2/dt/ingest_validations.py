from __future__ import annotations

import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dt.generate_dataset import append_row  # noqa: E402


def read_existing_keys(path: Path, voltage_names: list[str], round_v: float) -> set[tuple[float, ...]]:
    if not path.is_file():
        return set()
    keys: set[tuple[float, ...]] = set()
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                keys.add(tuple(round(float(row[name]), int(round_v)) for name in voltage_names))
            except (KeyError, TypeError, ValueError):
                continue
    return keys


def row_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(row.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def validation_to_dataset_row(
    source: Path, row: dict[str, str], voltage_names: list[str]
) -> dict[str, Any]:
    active = row_float(row, "sim_active", row_float(row, "active"))
    forward = row_float(row, "sim_forward", active)
    theta_mean = row_float(row, "sim_theta_mean", row_float(row, "theta_mean_deg"))
    theta_sigma = row_float(row, "sim_theta_sigma", row_float(row, "theta_sigma_deg"))
    theta_p95 = row_float(row, "sim_theta_p95")
    n_active = int(round(row_float(row, "sim_n_active", row_float(row, "speed_count"))))
    n_forward = int(round(row_float(row, "sim_n_forward", n_active)))
    n_backward = int(round(row_float(row, "sim_n_backward")))

    out: dict[str, Any] = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "sample_mode": f"validation_ingest_{source.stem}",
        "elapsed_seconds": row.get("elapsed_seconds", ""),
        "ions_flown": 500,
        "ions_reported": 500,
        "ions_detected": n_active,
        "ions_detected_geometric": n_active,
        "transmission": active,
        "transmission_geometric": active,
        "transmission_percent": 100.0 * active,
        "detector_contact_angle_count": n_active,
        "detector_contact_angle_forward": n_forward,
        "detector_contact_angle_backward": n_backward,
        "detector_contact_angle_theta_mean_deg": theta_mean,
        "detector_contact_angle_theta_sigma_deg": theta_sigma,
        "detector_contact_angle_theta_p95_deg": theta_p95,
        "detector_active_contact_count": n_active,
        "detector_active_contact_fraction": active,
        "detector_active_contact_percent": 100.0 * active,
        "detector_active_forward_fraction": forward,
        "bpm_real_score": row_float(row, "sim_bpm_score"),
    }
    speed_mean_key = "sim_speed_mean" if row.get("sim_speed_mean") not in ("", None) else "speed_mean"
    vz_mean_key = "sim_vz_mean" if row.get("sim_vz_mean") not in ("", None) else "vz_mean"
    vz_sigma_key = "sim_vz_sigma" if row.get("sim_vz_sigma") not in ("", None) else "vz_sigma"
    if row.get(speed_mean_key) not in ("", None):
        out["detector_contact_speed_speed_mean"] = row_float(row, speed_mean_key)
    if row.get(vz_mean_key) not in ("", None):
        out["detector_contact_speed_vz_mean"] = row_float(row, vz_mean_key)
    if row.get(vz_sigma_key) not in ("", None):
        out["detector_contact_speed_vz_sigma"] = row_float(row, vz_sigma_key)
    for name in voltage_names:
        out[name] = row_float(row, name)
    if "case" in row:
        out["validation_case"] = row["case"]
    if "rank" in row:
        out["validation_rank"] = row["rank"]
    return out


def iter_validation_files(paths: list[Path]) -> list[Path]:
    out: list[Path] = []
    for path in paths:
        if path.is_dir():
            out.extend(sorted(path.glob("*validation*.csv")))
            out.extend(sorted(path.glob("summary.csv")))
        elif path.is_file():
            out.append(path)
    unique: list[Path] = []
    seen = set()
    for path in out:
        resolved = path.resolve()
        if resolved not in seen:
            seen.add(resolved)
            unique.append(resolved)
    return unique


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ingiere validaciones SIMION al dataset DT para cerrar el ciclo de aprendizaje."
    )
    parser.add_argument("--dataset", type=Path, default=ROOT / "dt" / "data" / "dt_detector_window_dataset.csv")
    parser.add_argument(
        "--source",
        type=Path,
        action="append",
        default=[],
        help="CSV o carpeta con inverse_validation/summary.",
    )
    parser.add_argument(
        "--voltage-names",
        nargs="+",
        default=["V3", "V6", "V9", "V10", "V11", "V12", "V15", "V18"],
    )
    parser.add_argument("--dedupe-round", type=int, default=3)
    parser.add_argument("--include-duplicates", action="store_true")
    args = parser.parse_args()

    sources = args.source or [ROOT / "dt" / "data" / "inverse_sweep"]
    files = iter_validation_files([p.resolve() for p in sources])
    if not files:
        raise FileNotFoundError("No encontré CSVs de validación para ingerir.")

    existing = read_existing_keys(args.dataset.resolve(), args.voltage_names, args.dedupe_round)
    added = 0
    skipped = 0
    for path in files:
        with path.open("r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not all(name in row and row[name] not in ("", None) for name in args.voltage_names):
                    continue
                key = tuple(round(row_float(row, name), args.dedupe_round) for name in args.voltage_names)
                if key in existing and not args.include_duplicates:
                    skipped += 1
                    continue
                append_row(args.dataset.resolve(), validation_to_dataset_row(path, row, args.voltage_names))
                existing.add(key)
                added += 1
    print(f"Ingeridas: {added}; omitidas por duplicado: {skipped}; fuentes: {len(files)}")


if __name__ == "__main__":
    main()
