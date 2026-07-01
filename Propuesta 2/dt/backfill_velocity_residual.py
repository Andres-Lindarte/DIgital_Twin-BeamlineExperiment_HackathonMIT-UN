from __future__ import annotations

import argparse
import csv
import json
import random
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.derived_metrics import residual_from_row  # noqa: E402
from dt.generate_dataset import append_row, flatten_metrics, full_voltage_vector  # noqa: E402


DEFAULT_BINS = [
    ("t98_100", 0.98, 1.01, 0.30),
    ("t80_98", 0.80, 0.98, 0.25),
    ("t40_80", 0.40, 0.80, 0.20),
    ("t10_40", 0.10, 0.40, 0.15),
    ("t00_10", 0.00, 0.10, 0.10),
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def row_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(row.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def read_dataset(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def has_free_voltages(row: dict[str, str], names: list[str]) -> bool:
    for name in names:
        try:
            float(row[name])
        except (KeyError, TypeError, ValueError):
            return False
    return True


def voltage_key(row: dict[str, str], names: list[str], ndigits: int = 6) -> tuple[float, ...]:
    return tuple(round(row_float(row, name), ndigits) for name in names)


def allocate_counts(n: int, weights: list[float]) -> list[int]:
    raw = [n * w / sum(weights) for w in weights]
    counts = [int(x) for x in raw]
    while sum(counts) < n:
        remainders = [x - int(x) for x in raw]
        idx = max(range(len(weights)), key=lambda i: remainders[i])
        counts[idx] += 1
        raw[idx] = int(raw[idx])
    return counts


def select_rows(
    rows: list[dict[str, str]],
    voltage_names: list[str],
    n: int,
    seed: int,
) -> list[tuple[str, dict[str, str]]]:
    rng = random.Random(seed)
    keys_with_residual = {
        voltage_key(row, voltage_names)
        for row in rows
        if residual_from_row(row) is not None and has_free_voltages(row, voltage_names)
    }
    candidates = [
        row for row in rows
        if residual_from_row(row) is None
        and has_free_voltages(row, voltage_names)
        and voltage_key(row, voltage_names) not in keys_with_residual
    ]
    selected: list[tuple[str, dict[str, str]]] = []
    counts = allocate_counts(n, [item[3] for item in DEFAULT_BINS])
    used_ids: set[int] = set()

    for (label, lo, hi, _weight), count in zip(DEFAULT_BINS, counts):
        pool = [
            row for row in candidates
            if id(row) not in used_ids
            and lo <= row_float(row, "detector_active_contact_fraction", row_float(row, "transmission")) < hi
        ]
        # Favorece diversidad angular dentro de cada bin.
        pool.sort(key=lambda r: row_float(r, "detector_contact_angle_theta_sigma_deg"))
        if count <= 0 or not pool:
            continue
        if len(pool) <= count:
            picks = pool
        else:
            picks = []
            for i in range(count):
                idx = round(i * (len(pool) - 1) / max(1, count - 1))
                picks.append(pool[idx])
            # Rompe empates discretos sin perder cobertura.
            rng.shuffle(picks)
        for row in picks[:count]:
            used_ids.add(id(row))
            selected.append((label, row))

    if len(selected) < n:
        rest = [row for row in candidates if id(row) not in used_ids]
        rng.shuffle(rest)
        for row in rest[: n - len(selected)]:
            selected.append(("fallback", row))
    return selected[:n]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Re-corre puntos existentes sin residual de vz_sigma para balancear el DT."
    )
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--n", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260630)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    dataset_path = (ROOT / str(dt_cfg["output_dataset"])).resolve()
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    rows = read_dataset(dataset_path)
    selected = select_rows(rows, voltage_names, args.n, args.seed)
    if not selected:
        print("No encontré puntos existentes sin residual para backfill. Nada que hacer.")
        return

    print(f"Seleccionados {len(selected)} puntos existentes sin residual.")
    for i, (label, row) in enumerate(selected[: min(20, len(selected))], start=1):
        print(
            f"{i:03d} {label} active={100*row_float(row, 'detector_active_contact_fraction', row_float(row, 'transmission')):.2f}% "
            f"theta_sig={row_float(row, 'detector_contact_angle_theta_sigma_deg'):.3f} "
            + " ".join(f"{name}={row_float(row, name):.6g}" for name in voltage_names)
        )
    if args.dry_run:
        return

    simion_cfg = load_config(ROOT / str(dt_cfg["base_simion_config"]))
    simion_cfg["voltage_bounds"] = dt_cfg["full_bounds"]
    simion_cfg["fixed_voltages"] = dt_cfg["fixed_voltages"]
    simion_cfg["optimized_electrodes"] = [int(name[1:]) for name in voltage_names]

    for i, (label, old) in enumerate(selected, start=1):
        free = {name: row_float(old, name) for name in voltage_names}
        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        row: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "sample_mode": f"velocity_backfill_{label}",
            "elapsed_seconds": metadata.get("elapsed_seconds"),
            "backfill_source_active": row_float(old, "detector_active_contact_fraction", row_float(old, "transmission")),
            "backfill_source_theta_sigma": row_float(old, "detector_contact_angle_theta_sigma_deg"),
        }
        row.update(free)
        row.update(flatten_metrics(metrics))
        append_row(dataset_path, row)
        active = row_float({k: str(v) for k, v in row.items()}, "detector_active_contact_fraction")
        theta_sig = row_float({k: str(v) for k, v in row.items()}, "detector_contact_angle_theta_sigma_deg")
        vz_sig = row_float({k: str(v) for k, v in row.items()}, "detector_contact_speed_vz_sigma")
        print(
            f"{i:04d}/{len(selected)} {label} active={100*active:.2f}% "
            f"theta_sig={theta_sig:.3f} vz_sig={vz_sig:.4f} -> {dataset_path}",
            flush=True,
        )


if __name__ == "__main__":
    main()
