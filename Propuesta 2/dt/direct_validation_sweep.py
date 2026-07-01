from __future__ import annotations

import argparse
import csv
import json
import random
import sys
from pathlib import Path
from typing import Any

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.derived_metrics import add_predicted_derived_metrics, residual_from_row, vz_from_angle_normal  # noqa: E402
from dt.generate_dataset import full_voltage_vector  # noqa: E402
from dt.predict_dt import inverse_transform, load_model  # noqa: E402


VOLTAGE_NAMES = ["V3", "V6", "V9", "V10", "V11", "V12", "V15", "V18"]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def row_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(row.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def voltage_key(values: dict[str, float], ndigits: int = 3) -> tuple[float, ...]:
    return tuple(round(float(values[name]), ndigits) for name in VOLTAGE_NAMES)


def dataset_keys(path: Path) -> set[tuple[float, ...]]:
    if not path.is_file():
        return set()
    keys: set[tuple[float, ...]] = set()
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                keys.add(voltage_key({name: float(row[name]) for name in VOLTAGE_NAMES}))
            except (KeyError, TypeError, ValueError):
                continue
    return keys


def clip(values: dict[str, float], bounds: dict[str, list[float]]) -> dict[str, float]:
    return {
        name: max(float(bounds[name][0]), min(float(bounds[name][1]), float(values[name])))
        for name in VOLTAGE_NAMES
    }


def make_cases(dt_cfg: dict[str, Any], n: int, seed: int, known_keys: set[tuple[float, ...]]) -> list[tuple[str, dict[str, float]]]:
    rng = random.Random(seed)
    bounds = {str(k): [float(v[0]), float(v[1])] for k, v in dt_cfg["full_bounds"].items()}
    elites = [{str(k): float(v) for k, v in item["voltages"].items()} for item in dt_cfg["elites"]]
    cases: list[tuple[str, dict[str, float]]] = []
    seen = set(known_keys)

    # Casos fuera de la franja: intencionales, para probar que el DT dice "cero/no viable".
    forced = [
        ("outside_zero_free", {name: 0.0 for name in VOLTAGE_NAMES}),
        ("outside_opposite_bender", {
            "V3": 900.0,
            "V6": 900.0,
            "V9": -900.0,
            "V10": 700.0,
            "V11": 700.0,
            "V12": 900.0,
            "V15": 700.0,
            "V18": 700.0,
        }),
        ("outside_random_corner", {
            "V3": 1000.0,
            "V6": 1000.0,
            "V9": 1000.0,
            "V10": -1000.0,
            "V11": 1000.0,
            "V12": 1000.0,
            "V15": -1000.0,
            "V18": 1000.0,
        }),
    ]
    for label, values in forced:
        free = clip(values, bounds)
        cases.append((label, free))
        seen.add(voltage_key(free))

    def add(label: str, values: dict[str, float]) -> None:
        free = clip(values, bounds)
        key = voltage_key(free)
        if key in seen:
            return
        seen.add(key)
        cases.append((label, free))

    attempts = 0
    while len(cases) < n and attempts < n * 300:
        attempts += 1
        mode = rng.choices(
            ["near_elite_small", "near_elite_medium", "between_elites", "global_random"],
            weights=[0.35, 0.25, 0.25, 0.15],
            k=1,
        )[0]
        if mode == "near_elite_small":
            base = rng.choice(elites)
            sigma = rng.choice([8.0, 15.0, 25.0])
            add(mode, {name: base[name] + rng.gauss(0.0, sigma) for name in VOLTAGE_NAMES})
        elif mode == "near_elite_medium":
            base = rng.choice(elites)
            sigma = rng.choice([60.0, 100.0, 160.0])
            add(mode, {name: base[name] + rng.gauss(0.0, sigma) for name in VOLTAGE_NAMES})
        elif mode == "between_elites":
            a = rng.choice(elites)
            b = rng.choice(elites)
            t = rng.uniform(-0.15, 1.15)
            add(mode, {name: (1.0 - t) * a[name] + t * b[name] + rng.gauss(0.0, 15.0) for name in VOLTAGE_NAMES})
        else:
            add(mode, {name: rng.uniform(bounds[name][0], bounds[name][1]) for name in VOLTAGE_NAMES})
    return cases[:n]


def ensemble_predict(model_dir: Path, free: dict[str, float]) -> tuple[dict[str, float], dict[str, float]]:
    preds = []
    target_names: list[str] | None = None
    for model_path in sorted(model_dir.glob("model_seed_*.pt")):
        model, ckpt = load_model(model_path)
        input_names = [str(v) for v in ckpt["input_names"]]
        target_names = [str(v) for v in ckpt["target_names"]]
        x = np.asarray([[free[name] for name in input_names]], dtype=np.float32)
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            y_norm = model(torch.from_numpy(x_norm)).numpy()
        y_fit = y_norm * ckpt["y_std"] + ckpt["y_mean"]
        y = inverse_transform(y_fit, target_names, str(ckpt.get("target_transform", "identity")))
        preds.append(y[0])
    if not preds or target_names is None:
        raise FileNotFoundError(f"No encontré modelos en {model_dir}")
    arr = np.vstack(preds)
    mean = {f"pred_{name}": float(value) for name, value in zip(target_names, arr.mean(axis=0))}
    unc = {f"unc_{name}": float(value) for name, value in zip(target_names, arr.std(axis=0))}
    add_predicted_derived_metrics(mean)
    return mean, unc


def metric(metrics: dict[str, Any], key: str, default: float = 0.0) -> float:
    try:
        return float(metrics.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def clamp_predicted_metrics(row: dict[str, Any]) -> None:
    if "pred_detector_active_contact_fraction" in row:
        row["pred_active_clipped"] = max(0.0, min(1.0, float(row["pred_detector_active_contact_fraction"])))
    if "pred_detector_active_forward_fraction" in row:
        row["pred_forward_clipped"] = max(0.0, min(1.0, float(row["pred_detector_active_forward_fraction"])))
    if "pred_detector_contact_angle_theta_mean_deg" in row:
        row["pred_theta_mean_clipped"] = max(0.0, float(row["pred_detector_contact_angle_theta_mean_deg"]))
    if "pred_detector_contact_angle_theta_sigma_deg" in row:
        row["pred_theta_sigma_clipped"] = max(0.0, float(row["pred_detector_contact_angle_theta_sigma_deg"]))
    if "derived_vz_sigma_corrected" in row:
        row["pred_vz_sigma_corrected_clipped"] = max(0.0, float(row["derived_vz_sigma_corrected"]))


def main() -> None:
    parser = argparse.ArgumentParser(description="Valida el DT directo en puntos no entrenados.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--simion-config", type=Path, default=ROOT / "optuna_config_hackathon_detector_window_quality_v17.json")
    parser.add_argument("--model-dir", type=Path, default=ROOT / "dt" / "models" / "baseline_mlp")
    parser.add_argument("--n", type=int, default=24)
    parser.add_argument("--seed", type=int, default=20260702)
    parser.add_argument("--out", type=Path, default=ROOT / "dt" / "data" / "direct_validation_sweep.csv")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    dataset_path = ROOT / str(dt_cfg["output_dataset"])
    known = dataset_keys(dataset_path)
    cases = make_cases(dt_cfg, args.n, args.seed, known)
    simion_cfg = load_config(args.simion_config.resolve())
    rows: list[dict[str, Any]] = []

    for i, (label, free) in enumerate(cases, start=1):
        pred, unc = ensemble_predict(args.model_dir.resolve(), free)
        row: dict[str, Any] = {"i": i, "case": label, **free, **pred, **unc}
        clamp_predicted_metrics(row)
        if args.dry_run:
            rows.append(row)
            print(f"{i:02d}/{len(cases)} {label} DRY " + " ".join(f"{k}={free[k]:.4g}" for k in VOLTAGE_NAMES))
            continue

        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        row.update({
            "elapsed_seconds": metadata.get("elapsed_seconds"),
            "sim_active": metric(metrics, "detector_active_contact_fraction"),
            "sim_forward": metric(metrics, "detector_active_forward_fraction"),
            "sim_theta_mean": metric(metrics, "detector_contact_angle_theta_mean_deg"),
            "sim_theta_sigma": metric(metrics, "detector_contact_angle_theta_sigma_deg"),
            "sim_vz_mean": metric(metrics, "detector_contact_speed_vz_mean"),
            "sim_vz_sigma": metric(metrics, "detector_contact_speed_vz_sigma"),
        })
        sim_physics = vz_from_angle_normal(
            row["sim_theta_mean"],
            row["sim_theta_sigma"],
            metric(metrics, "detector_contact_speed_speed_mean", 130.62) or 130.62,
        )
        row["sim_vz_sigma_physics"] = sim_physics["derived_vz_sigma_physics"]
        residual = residual_from_row({
            "detector_contact_angle_theta_mean_deg": row["sim_theta_mean"],
            "detector_contact_angle_theta_sigma_deg": row["sim_theta_sigma"],
            "detector_contact_speed_speed_mean": metric(metrics, "detector_contact_speed_speed_mean", 130.62),
            "detector_contact_speed_vz_sigma": row["sim_vz_sigma"],
        })
        row["sim_vz_sigma_residual"] = "" if residual is None else residual
        row["err_active"] = row.get("pred_detector_active_contact_fraction", 0.0) - row["sim_active"]
        row["err_active_clipped"] = row.get("pred_active_clipped", 0.0) - row["sim_active"]
        row["err_theta_mean"] = row.get("pred_detector_contact_angle_theta_mean_deg", 0.0) - row["sim_theta_mean"]
        row["err_theta_mean_clipped"] = row.get("pred_theta_mean_clipped", 0.0) - row["sim_theta_mean"]
        row["err_theta_sigma"] = row.get("pred_detector_contact_angle_theta_sigma_deg", 0.0) - row["sim_theta_sigma"]
        row["err_theta_sigma_clipped"] = row.get("pred_theta_sigma_clipped", 0.0) - row["sim_theta_sigma"]
        row["err_vz_sigma_corrected"] = row.get("derived_vz_sigma_corrected", 0.0) - row["sim_vz_sigma"]
        row["err_vz_sigma_corrected_clipped"] = row.get("pred_vz_sigma_corrected_clipped", 0.0) - row["sim_vz_sigma"]
        rows.append(row)
        print(
            f"{i:02d}/{len(cases)} {label} "
            f"active pred/sim={100*row.get('pred_active_clipped', 0.0):5.1f}/{100*row['sim_active']:5.1f}% "
            f"theta_sig pred/sim={row.get('pred_theta_sigma_clipped', 0.0):5.2f}/{row['sim_theta_sigma']:5.2f} "
            f"vz_sig pred/sim={row.get('pred_vz_sigma_corrected_clipped', 0.0):5.3f}/{row['sim_vz_sigma']:5.3f}",
            flush=True,
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row.keys():
            if key not in fieldnames:
                fieldnames.append(key)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    if not args.dry_run and rows:
        print(f"\nCSV: {args.out}")
        for key in ["err_active_clipped", "err_theta_mean_clipped", "err_theta_sigma_clipped", "err_vz_sigma_corrected_clipped"]:
            vals = [abs(float(r[key])) for r in rows if key in r and r[key] not in ("", None)]
            if vals:
                print(f"MAE {key}: {sum(vals)/len(vals):.6g}")
    else:
        print(f"CSV: {args.out}")


if __name__ == "__main__":
    main()
