from __future__ import annotations

import argparse
import csv
import json
import math
import random
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.generate_dataset import append_row, flatten_metrics, full_voltage_vector, load_json  # noqa: E402


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def run_cmd(cmd: list[str], log_path: Path) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as log:
        proc = subprocess.run(
            cmd,
            cwd=str(ROOT),
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
    if proc.returncode != 0:
        raise RuntimeError(f"Falló comando; revise {log_path}")


def train_model(
    run_dir: Path,
    dataset_path: Path,
    cycle: int,
    ensemble_size: int,
    epochs: int,
) -> Path:
    model_dir = run_dir / "models" / f"model_cycle_{cycle:03d}"
    cmd = [
        sys.executable,
        str(ROOT / "dt" / "train_dt.py"),
        "--data",
        str(dataset_path),
        "--model-dir",
        str(model_dir),
        "--ensemble-size",
        str(int(ensemble_size)),
        "--epochs",
        str(int(epochs)),
    ]
    run_cmd(cmd, run_dir / "logs" / f"train_cycle_{cycle:03d}.log")
    return model_dir


def train_viability(
    run_dir: Path,
    dataset_path: Path,
    cycle: int,
    ensemble_size: int,
    epochs: int,
    threshold: float,
) -> Path:
    model_dir = run_dir / "models" / f"viability_cycle_{cycle:03d}"
    cmd = [
        sys.executable,
        str(ROOT / "dt" / "train_viability.py"),
        "--data",
        str(dataset_path),
        "--model-dir",
        str(model_dir),
        "--ensemble-size",
        str(int(ensemble_size)),
        "--epochs",
        str(int(epochs)),
        "--threshold",
        str(float(threshold)),
    ]
    run_cmd(cmd, run_dir / "logs" / f"train_viability_cycle_{cycle:03d}.log")
    return model_dir


def generate_targets(
    n: int,
    rng: random.Random,
    cycle: int,
    min_active: float,
    mode: str,
) -> list[dict[str, float | str]]:
    # Lección de test_v1: pedir demasiado 30-40% produce fallos catastróficos
    # útiles, pero lentos para bajar el umbral. Por defecto densificamos 50-90%.
    if mode == "broad":
        active_pool = [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80, 0.90, 0.98]
    elif mode == "low":
        active_pool = [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60]
    else:
        active_pool = [0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.96, 0.99]
    active_pool = [max(float(min_active), x) for x in active_pool]
    targets: list[dict[str, float | str]] = []
    for i in range(n):
        if i < len(active_pool):
            active = active_pool[(i + cycle) % len(active_pool)]
        else:
            active = rng.choice(active_pool) + rng.uniform(-0.035, 0.035)
            active = max(float(min_active), min(1.0, active))
        theta_mean = rng.choice([2.5, 3.5, 4.5, 5.5, 6.5]) + rng.uniform(-0.35, 0.35)
        theta_sigma = rng.choice([1.0, 1.5, 2.0, 2.5, 3.0]) + rng.uniform(-0.20, 0.20)
        targets.append(
            {
                "target_name": f"cycle{cycle:03d}_target{i+1:02d}",
                "target_active": float(active),
                "target_theta_mean": float(max(0.5, theta_mean)),
                "target_theta_sigma": float(max(0.3, theta_sigma)),
            }
        )
    return targets


def inverse_design_for_target(
    run_dir: Path,
    cycle: int,
    target: dict[str, float | str],
    model_dir: Path,
    viability_dir: Path | None,
    n_starts: int,
    steps: int,
    top_k: int,
    seed: int,
) -> Path:
    name = str(target["target_name"])
    out_path = run_dir / "candidates" / f"{name}.csv"
    cmd = [
        sys.executable,
        str(ROOT / "dt" / "inverse_design.py"),
        "--model-dir",
        str(model_dir),
        "--target-active",
        str(float(target["target_active"])),
        "--target-forward",
        "1.0",
        "--target-theta-mean",
        str(float(target["target_theta_mean"])),
        "--target-theta-sigma",
        str(float(target["target_theta_sigma"])),
        "--no-minimize-theta-sigma",
        "--n-starts",
        str(int(n_starts)),
        "--steps",
        str(int(steps)),
        "--top-k",
        str(int(top_k)),
        "--out",
        str(out_path),
        "--seed",
        str(int(seed)),
    ]
    if viability_dir is not None:
        cmd.extend(
            [
                "--viability-model-dir",
                str(viability_dir),
                "--min-viability-prob",
                "0.45",
                "--w-viability",
                "2.0",
            ]
        )
    run_cmd(cmd, run_dir / "logs" / f"inverse_{name}.log")
    return out_path


def read_candidate_file(
    path: Path,
    target: dict[str, float | str],
    voltage_names: list[str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for rank, row in enumerate(read_rows(path), start=1):
        try:
            free = {name: float(row[name]) for name in voltage_names}
        except (KeyError, TypeError, ValueError):
            continue
        item: dict[str, Any] = {
            "candidate_source": path.name,
            "candidate_rank": rank,
            **target,
            **free,
        }
        for key, value in row.items():
            if key.startswith("pred_") or key.startswith("unc_") or key in {"loss"}:
                item[key] = value
        rows.append(item)
    return rows


def voltage_vector(candidate: dict[str, Any], voltage_names: list[str]) -> np.ndarray:
    return np.asarray([float(candidate[name]) for name in voltage_names], dtype=np.float64)


def select_diverse(
    candidates: list[dict[str, Any]],
    voltage_names: list[str],
    n: int,
    rng: random.Random,
) -> list[dict[str, Any]]:
    if len(candidates) <= n:
        return candidates
    # Protege el mejor de cada consigna.
    by_target: dict[str, list[dict[str, Any]]] = {}
    for cand in candidates:
        by_target.setdefault(str(cand["target_name"]), []).append(cand)
    selected: list[dict[str, Any]] = []
    for rows in by_target.values():
        rows.sort(key=lambda r: float(r.get("loss") or 1e9))
        selected.append(rows[0])
        if len(selected) >= n:
            return selected

    rest = [c for c in candidates if c not in selected]
    rng.shuffle(rest)
    scale = np.asarray([2000.0 for _ in voltage_names], dtype=np.float64)
    while len(selected) < n and rest:
        best_idx = 0
        best_score = -1.0
        selected_vecs = [voltage_vector(c, voltage_names) / scale for c in selected]
        for i, cand in enumerate(rest):
            v = voltage_vector(cand, voltage_names) / scale
            dist = min(float(np.linalg.norm(v - s)) for s in selected_vecs)
            loss_bonus = 1.0 / (1.0 + float(cand.get("loss") or 0.0))
            score = dist + 0.05 * loss_bonus
            if score > best_score:
                best_score = score
                best_idx = i
        selected.append(rest.pop(best_idx))
    return selected


def perturb_candidates(
    candidates: list[dict[str, Any]],
    dt_cfg: dict[str, Any],
    voltage_names: list[str],
    n: int,
    rng: random.Random,
) -> list[dict[str, Any]]:
    if not candidates or n <= 0:
        return []
    bounds = dt_cfg["full_bounds"]
    out: list[dict[str, Any]] = []
    sigmas = [8.0, 15.0, 30.0, 60.0]
    for i in range(n):
        base = rng.choice(candidates)
        cand = dict(base)
        cand["candidate_source"] = "local_perturbation"
        cand["candidate_rank"] = 10_000 + i
        sigma = rng.choice(sigmas)
        for name in voltage_names:
            lo, hi = [float(x) for x in bounds[name]]
            cand[name] = max(lo, min(hi, float(base[name]) + rng.gauss(0.0, sigma)))
        out.append(cand)
    return out


def is_good_for_local_perturbation(row: dict[str, Any]) -> bool:
    try:
        active = float(row["detector_active_contact_fraction"])
        target = float(row["target_active"])
        inv_err = float(row["inverse_total_error"])
    except (KeyError, TypeError, ValueError):
        return False
    # Evita gastar perturbaciones alrededor de desastres 0% o saltos enormes.
    if active < 0.15:
        return False
    if abs(active - target) > 0.30:
        return False
    return inv_err < 1.75


def metric(metrics: dict[str, Any], key: str) -> float:
    try:
        return float(metrics.get(key, 0.0))
    except (TypeError, ValueError):
        return 0.0


def validate_candidate(
    simion_cfg: dict[str, Any],
    dt_cfg: dict[str, Any],
    candidate: dict[str, Any],
    voltage_names: list[str],
    cycle: int,
    index: int,
) -> dict[str, Any]:
    free = {name: float(candidate[name]) for name in voltage_names}
    metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
    row: dict[str, Any] = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "cycle": cycle,
        "inverse_index": index,
        "sample_mode": "inverse_active",
        "elapsed_seconds": metadata.get("elapsed_seconds"),
        **{name: free[name] for name in voltage_names},
        "target_name": candidate.get("target_name"),
        "target_active": candidate.get("target_active"),
        "target_theta_mean": candidate.get("target_theta_mean"),
        "target_theta_sigma": candidate.get("target_theta_sigma"),
        "candidate_source": candidate.get("candidate_source"),
        "candidate_rank": candidate.get("candidate_rank"),
        "candidate_loss": candidate.get("loss"),
    }
    for key, value in candidate.items():
        if key.startswith("pred_") or key.startswith("unc_"):
            row[key] = value
    row.update(flatten_metrics(metrics))
    active = metric(metrics, "detector_active_contact_fraction")
    theta_mean = metric(metrics, "detector_contact_angle_theta_mean_deg")
    theta_sigma = metric(metrics, "detector_contact_angle_theta_sigma_deg")
    row["inverse_abs_error_active"] = abs(active - float(candidate["target_active"]))
    row["inverse_abs_error_theta_mean"] = abs(theta_mean - float(candidate["target_theta_mean"]))
    row["inverse_abs_error_theta_sigma"] = abs(theta_sigma - float(candidate["target_theta_sigma"]))
    row["inverse_total_error"] = (
        4.0 * row["inverse_abs_error_active"]
        + 0.25 * row["inverse_abs_error_theta_mean"]
        + 0.25 * row["inverse_abs_error_theta_sigma"]
    )
    return row


def append_log(run_dir: Path, text: str) -> None:
    with (run_dir / "run.log").open("a", encoding="utf-8") as f:
        f.write(text.rstrip() + "\n")


def summarize_dataset(path: Path) -> dict[str, Any]:
    rows = read_rows(path)
    values = []
    inv_errors = []
    for row in rows:
        try:
            values.append(float(row["detector_active_contact_fraction"]))
        except (KeyError, TypeError, ValueError):
            pass
        try:
            inv_errors.append(float(row["inverse_total_error"]))
        except (KeyError, TypeError, ValueError):
            pass
    return {
        "rows": len(rows),
        "best_active": None if not values else max(values),
        "mean_active": None if not values else float(np.mean(values)),
        "inverse_rows": len(inv_errors),
        "mean_inverse_error": None if not inv_errors else float(np.mean(inv_errors)),
        "median_inverse_error": None if not inv_errors else float(np.median(inv_errors)),
    }


def copy_seed_data(seed_data: Path, dataset_path: Path, seed_rows: int | None) -> None:
    if seed_rows is None or seed_rows <= 0:
        shutil.copyfile(seed_data, dataset_path)
        return
    rows = read_rows(seed_data)[: int(seed_rows)]
    if not rows:
        raise ValueError(f"No hay filas para copiar desde {seed_data}")
    header: list[str] = []
    for row in rows:
        for key in row.keys():
            if key not in header:
                header.append(key)
    dataset_path.parent.mkdir(parents=True, exist_ok=True)
    with dataset_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Aprendizaje activo orientado a fallos de consigna inversa."
    )
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--seed-data", type=Path, default=None)
    parser.add_argument("--seed-rows", type=int, default=None)
    parser.add_argument("--cycles", type=int, default=4)
    parser.add_argument("--simions-per-cycle", type=int, default=50)
    parser.add_argument("--targets-per-cycle", type=int, default=18)
    parser.add_argument("--inverse-top-k", type=int, default=4)
    parser.add_argument("--local-perturb-fraction", type=float, default=0.25)
    parser.add_argument("--target-mode", choices=["focused", "broad", "low"], default="focused")
    parser.add_argument("--min-target-active", type=float, default=0.48)
    parser.add_argument("--ensemble-size", type=int, default=3)
    parser.add_argument("--epochs", type=int, default=350)
    parser.add_argument("--viability-epochs", type=int, default=200)
    parser.add_argument("--n-starts", type=int, default=160)
    parser.add_argument("--inverse-steps", type=int, default=450)
    parser.add_argument("--seed", type=int, default=20260705)
    parser.add_argument("--no-viability", action="store_true")
    args = parser.parse_args()

    rng = random.Random(int(args.seed))
    dt_cfg = load_json(args.config.resolve())
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    run_dir = (ROOT / args.run_dir if not args.run_dir.is_absolute() else args.run_dir).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    dataset_path = run_dir / "dataset.csv"

    if args.seed_data is not None and not dataset_path.is_file():
        seed_data = (ROOT / args.seed_data if not args.seed_data.is_absolute() else args.seed_data).resolve()
        copy_seed_data(seed_data, dataset_path, args.seed_rows)

    if not dataset_path.is_file():
        raise FileNotFoundError(
            "Este loop necesita --seed-data para entrenar el primer DT. "
            "Use un dataset previo o una corrida budget_simion parcial."
        )

    simion_cfg = load_config(ROOT / str(dt_cfg["base_simion_config"]))
    simion_cfg["voltage_bounds"] = dt_cfg["full_bounds"]
    simion_cfg["fixed_voltages"] = dt_cfg["fixed_voltages"]
    simion_cfg["optimized_electrodes"] = [int(name[1:]) for name in voltage_names]

    write_json(
        run_dir / "run_config.json",
        {
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "seed_data": None if args.seed_data is None else str(args.seed_data),
            "seed_rows": args.seed_rows,
            "cycles": int(args.cycles),
            "simions_per_cycle": int(args.simions_per_cycle),
            "targets_per_cycle": int(args.targets_per_cycle),
            "note": "Loop orientado a fallos de consigna inversa; dataset fusionable.",
        },
    )

    print(f"Run dir: {run_dir}")
    print(f"Dataset: {dataset_path}")

    global_index = 0
    for cycle in range(1, int(args.cycles) + 1):
        print(f"\n=== Ciclo inverso {cycle}/{args.cycles} ===", flush=True)
        model_dir = train_model(run_dir, dataset_path, cycle, args.ensemble_size, args.epochs)
        viability_dir = None
        if not args.no_viability:
            viability_dir = train_viability(
                run_dir,
                dataset_path,
                cycle,
                args.ensemble_size,
                args.viability_epochs,
                threshold=0.02,
            )

        targets = generate_targets(
            args.targets_per_cycle,
            rng,
            cycle,
            min_active=float(args.min_target_active),
            mode=str(args.target_mode),
        )
        all_candidates: list[dict[str, Any]] = []
        for i, target in enumerate(targets, start=1):
            cand_path = inverse_design_for_target(
                run_dir,
                cycle,
                target,
                model_dir,
                viability_dir,
                args.n_starts,
                args.inverse_steps,
                args.inverse_top_k,
                seed=int(args.seed) + cycle * 1000 + i,
            )
            all_candidates.extend(read_candidate_file(cand_path, target, voltage_names))

        base_n = max(1, int(round(args.simions_per_cycle * (1.0 - args.local_perturb_fraction))))
        selected = select_diverse(all_candidates, voltage_names, base_n, rng)
        validated_rows: list[dict[str, Any]] = []

        for cand in selected[:base_n]:
            global_index += 1
            row = validate_candidate(simion_cfg, dt_cfg, cand, voltage_names, cycle, global_index)
            validated_rows.append(row)
            append_row(dataset_path, row)
            print(
                f"{global_index:04d} cycle={cycle} "
                f"target={float(row['target_active']):.2f} "
                f"active={100*float(row['detector_active_contact_fraction']):.2f}% "
                f"theta={float(row['detector_contact_angle_theta_mean_deg']):.3f} "
                f"sig={float(row['detector_contact_angle_theta_sigma_deg']):.3f} "
                f"err={float(row['inverse_total_error']):.3f}",
                flush=True,
            )

        good_bases = [
            {**row, **{name: float(row[name]) for name in voltage_names}}
            for row in validated_rows
            if is_good_for_local_perturbation(row)
        ]
        if not good_bases:
            good_bases = selected[:base_n]
        perturb = perturb_candidates(
            good_bases,
            dt_cfg,
            voltage_names,
            args.simions_per_cycle - len(validated_rows),
            rng,
        )
        for cand in perturb:
            global_index += 1
            row = validate_candidate(simion_cfg, dt_cfg, cand, voltage_names, cycle, global_index)
            append_row(dataset_path, row)
            print(
                f"{global_index:04d} cycle={cycle} perturb "
                f"target={float(row['target_active']):.2f} "
                f"active={100*float(row['detector_active_contact_fraction']):.2f}% "
                f"theta={float(row['detector_contact_angle_theta_mean_deg']):.3f} "
                f"sig={float(row['detector_contact_angle_theta_sigma_deg']):.3f} "
                f"err={float(row['inverse_total_error']):.3f}",
                flush=True,
            )

        summary = summarize_dataset(dataset_path)
        write_json(run_dir / "state.json", {"cycle": cycle, "summary": summary})
        append_log(run_dir, f"CYCLE {cycle} {json.dumps(summary, ensure_ascii=False)}")

    print("\nTerminado.")
    print(f"Dataset: {dataset_path}")
    print(f"Estado: {run_dir / 'state.json'}")


if __name__ == "__main__":
    main()
