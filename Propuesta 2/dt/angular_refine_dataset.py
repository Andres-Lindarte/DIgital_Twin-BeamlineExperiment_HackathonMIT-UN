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
from dt.generate_dataset import append_row, flatten_metrics, full_voltage_vector  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


def read_candidate_csv(path: Path, voltage_names: list[str], max_rows: int | None = None) -> list[dict[str, float]]:
    if not path.is_file():
        return []
    out = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                out.append({name: float(row[name]) for name in voltage_names})
            except (KeyError, TypeError, ValueError):
                continue
            if max_rows is not None and len(out) >= max_rows:
                break
    return out


def seed_points(dt_cfg: dict[str, Any], voltage_names: list[str], include_inverse: bool) -> list[dict[str, float]]:
    seeds = []
    for item in dt_cfg.get("elites", []):
        try:
            seeds.append({name: float(item["voltages"][name]) for name in voltage_names})
        except KeyError:
            continue
    if include_inverse:
        data_dir = ROOT / "dt" / "data"
        for path in sorted(data_dir.glob("inverse_candidates*.csv")):
            seeds.extend(read_candidate_csv(path, voltage_names, max_rows=20))
        for path in sorted(data_dir.glob("inverse_validation*.csv")):
            seeds.extend(read_candidate_csv(path, voltage_names, max_rows=20))
    # dedupe aproximado
    unique = []
    seen = set()
    for s in seeds:
        key = tuple(round(s[name], 2) for name in voltage_names)
        if key not in seen:
            seen.add(key)
            unique.append(s)
    return unique


def perturb(
    base: dict[str, float],
    voltage_names: list[str],
    bounds: dict[str, list[float]],
    rng: random.Random,
    mode: str,
) -> dict[str, float]:
    sigmas = {
        "tiny": 5.0,
        "small": 12.0,
        "medium": 25.0,
        "axis": 0.0,
        "pair": 0.0,
    }
    out = dict(base)
    if mode in ("tiny", "small", "medium"):
        sigma = sigmas[mode]
        for name in voltage_names:
            out[name] = out[name] + rng.gauss(0.0, sigma)
    elif mode == "axis":
        name = rng.choice(voltage_names)
        step = rng.choice([-50, -30, -20, -10, -5, 5, 10, 20, 30, 50])
        out[name] = out[name] + step
    elif mode == "pair":
        a, b = rng.sample(voltage_names, 2)
        step = rng.choice([-35, -20, -10, 10, 20, 35])
        out[a] = out[a] + step
        out[b] = out[b] + rng.choice([-1, 1]) * step * rng.uniform(0.5, 1.5)
    for name in voltage_names:
        lo, hi = [float(v) for v in bounds[name]]
        out[name] = clamp(float(out[name]), lo, hi)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Agrega datos locales para calibrar ángulo en zona viable.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--simion-config", type=Path, default=ROOT / "optuna_config_hackathon_detector_window_quality_v17.json")
    parser.add_argument("--n", type=int, default=300)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--include-inverse", action="store_true", default=True)
    args = parser.parse_args()

    rng = random.Random(args.seed if args.seed is not None else random.SystemRandom().randint(1, 2_000_000_000))
    dt_cfg = load_json(args.config.resolve())
    simion_cfg = load_config(args.simion_config.resolve())
    out_path = (ROOT / str(dt_cfg["output_dataset"])).resolve()
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    bounds = {str(k): [float(v[0]), float(v[1])] for k, v in dt_cfg["full_bounds"].items()}
    seeds = seed_points(dt_cfg, voltage_names, include_inverse=args.include_inverse)
    if not seeds:
        raise RuntimeError("No hay semillas para refinamiento angular.")

    modes = ["tiny", "small", "small", "medium", "axis", "axis", "pair"]
    for i in range(1, args.n + 1):
        base = rng.choice(seeds)
        mode = rng.choice(modes)
        free = perturb(base, voltage_names, bounds, rng, mode)
        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        row: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "sample_mode": f"angular_refine_{mode}",
            "elapsed_seconds": metadata.get("elapsed_seconds"),
        }
        row.update(free)
        row.update(flatten_metrics(metrics))
        append_row(out_path, row)
        print(
            f"{i:04d}/{args.n} {mode} "
            f"active={100*float(metrics.get('detector_active_contact_fraction') or 0.0):.2f}% "
            f"mu={float(metrics.get('detector_contact_angle_theta_mean_deg') or 0.0):.3f} "
            f"sig={float(metrics.get('detector_contact_angle_theta_sigma_deg') or 0.0):.3f}"
        )


if __name__ == "__main__":
    main()
