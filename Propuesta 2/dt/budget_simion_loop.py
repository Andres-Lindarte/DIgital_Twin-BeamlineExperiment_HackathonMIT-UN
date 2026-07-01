from __future__ import annotations

import argparse
import csv
import json
import math
import random
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402
from dt.generate_dataset import (  # noqa: E402
    CandidateSampler,
    append_row,
    existing_keys,
    flatten_metrics,
    full_voltage_vector,
    key_for,
    load_json,
    olhs_points,
)
from dt.predict_dt import inverse_transform, load_model  # noqa: E402


BIN_QUOTAS = {
    "dead": 0.05,
    "low": 0.20,
    "transition": 0.30,
    "high": 0.25,
    "elite": 0.20,
}


class ViabilityMLP(torch.nn.Module):
    def __init__(self, n_in: int, hidden: list[int], dropout: float):
        super().__init__()
        layers: list[torch.nn.Module] = []
        last = n_in
        for width in hidden:
            layers.append(torch.nn.Linear(last, int(width)))
            layers.append(torch.nn.GELU())
            if dropout > 0:
                layers.append(torch.nn.Dropout(float(dropout)))
            last = int(width)
        layers.append(torch.nn.Linear(last, 1))
        self.net = torch.nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)


def now_slug() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def count_valid_rows(path: Path, voltage_names: list[str]) -> int:
    n = 0
    for row in read_rows(path):
        if row.get("simion_error"):
            continue
        try:
            [float(row[name]) for name in voltage_names]
        except (KeyError, TypeError, ValueError):
            continue
        n += 1
    return n


def contact_from_row(row: dict[str, str]) -> float | None:
    for name in (
        "detector_active_contact_fraction",
        "detector_contact_fraction",
        "transmission",
    ):
        try:
            return float(row[name])
        except (KeyError, TypeError, ValueError):
            pass
    return None


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def train_snapshot(
    run_dir: Path,
    dataset_path: Path,
    model_dir: Path,
    ensemble_size: int,
    epochs: int,
) -> dict[str, Any]:
    log_path = run_dir / "logs" / f"train_{model_dir.name}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
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
    with log_path.open("w", encoding="utf-8") as log:
        proc = subprocess.run(
            cmd,
            cwd=str(ROOT),
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
    if proc.returncode != 0:
        raise RuntimeError(f"Falló entrenamiento; revise {log_path}")
    summary_path = model_dir / "training_summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["log_path"] = str(log_path)
    return summary


def train_viability_snapshot(
    run_dir: Path,
    dataset_path: Path,
    model_dir: Path,
    ensemble_size: int,
    epochs: int,
    threshold: float,
) -> dict[str, Any]:
    log_path = run_dir / "logs" / f"train_{model_dir.name}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
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
    with log_path.open("w", encoding="utf-8") as log:
        proc = subprocess.run(
            cmd,
            cwd=str(ROOT),
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )
    if proc.returncode != 0:
        raise RuntimeError(f"Falló entrenamiento de viabilidad; revise {log_path}")
    summary_path = model_dir / "viability_summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["log_path"] = str(log_path)
    return summary


def latest_model_dir(run_dir: Path) -> Path | None:
    model_root = run_dir / "models"
    if not model_root.is_dir():
        return None
    candidates = sorted(
        [p for p in model_root.glob("model_after_*") if (p / "training_summary.json").is_file()]
    )
    return candidates[-1] if candidates else None


def latest_viability_dir(run_dir: Path) -> Path | None:
    model_root = run_dir / "models"
    if not model_root.is_dir():
        return None
    candidates = sorted(
        [p for p in model_root.glob("viability_after_*") if (p / "viability_summary.json").is_file()]
    )
    return candidates[-1] if candidates else None


def load_ensemble(model_dir: Path):
    loaded = []
    for model_path in sorted(model_dir.glob("model_seed_*.pt")):
        loaded.append(load_model(model_path))
    if not loaded:
        raise FileNotFoundError(f"No encontré modelos en {model_dir}")
    return loaded


def load_viability_ensemble(model_dir: Path | None):
    if model_dir is None:
        return []
    loaded = []
    for model_path in sorted(model_dir.glob("viability_seed_*.pt")):
        ckpt = torch.load(model_path, map_location="cpu", weights_only=False)
        model = ViabilityMLP(
            len(ckpt["input_names"]),
            [int(v) for v in ckpt["hidden_layers"]],
            float(ckpt.get("dropout", 0.0)),
        )
        model.load_state_dict(ckpt["state_dict"])
        model.eval()
        loaded.append((model, ckpt))
    return loaded


def predict_pool(
    loaded_models: list[tuple[torch.nn.Module, dict[str, Any]]],
    candidates: list[dict[str, float]],
) -> tuple[np.ndarray, np.ndarray, list[str]]:
    preds: list[np.ndarray] = []
    target_names: list[str] | None = None
    for model, ckpt in loaded_models:
        input_names = [str(v) for v in ckpt["input_names"]]
        target_names = [str(v) for v in ckpt["target_names"]]
        x = np.asarray(
            [[float(candidate[name]) for name in input_names] for candidate in candidates],
            dtype=np.float32,
        )
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            y_norm = model(torch.from_numpy(x_norm)).numpy()
        y_fit = y_norm * ckpt["y_std"] + ckpt["y_mean"]
        y = inverse_transform(y_fit, target_names, str(ckpt.get("target_transform", "identity")))
        preds.append(y)
    arr = np.stack(preds, axis=0)
    return arr.mean(axis=0), arr.std(axis=0), target_names or []


def predict_viability_pool(
    loaded_models: list[tuple[torch.nn.Module, dict[str, Any]]],
    candidates: list[dict[str, float]],
) -> tuple[np.ndarray | None, np.ndarray | None]:
    if not loaded_models:
        return None, None
    preds: list[np.ndarray] = []
    for model, ckpt in loaded_models:
        input_names = [str(v) for v in ckpt["input_names"]]
        x = np.asarray(
            [[float(candidate[name]) for name in input_names] for candidate in candidates],
            dtype=np.float32,
        )
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            logits = model(torch.from_numpy(x_norm)).numpy()
        preds.append(1.0 / (1.0 + np.exp(-logits)))
    arr = np.stack(preds, axis=0)
    return arr.mean(axis=0), arr.std(axis=0)


def target_index(names: list[str], *options: str) -> int | None:
    for option in options:
        if option in names:
            return names.index(option)
    return None


def bin_for_contact(contact: float) -> str:
    if contact < 0.02:
        return "dead"
    if contact < 0.20:
        return "low"
    if contact < 0.60:
        return "transition"
    if contact < 0.95:
        return "high"
    return "elite"


def pool_score(
    mean: np.ndarray,
    std: np.ndarray,
    names: list[str],
    viability_mean: np.ndarray | None = None,
    viability_std: np.ndarray | None = None,
) -> tuple[np.ndarray, list[str]]:
    idx_contact = target_index(
        names,
        "detector_active_contact_fraction",
        "detector_contact_fraction",
        "transmission",
    )
    idx_forward = target_index(names, "detector_active_forward_fraction")
    idx_theta_mean = target_index(names, "detector_contact_angle_theta_mean_deg")
    idx_theta_sig = target_index(names, "detector_contact_angle_theta_sigma_deg")
    idx_resid = target_index(names, "derived_vz_sigma_residual")

    n = len(mean)
    score = np.zeros(n, dtype=np.float64)
    contact = np.zeros(n, dtype=np.float64) if idx_contact is None else np.clip(mean[:, idx_contact], 0.0, 1.0)
    bins = [bin_for_contact(float(v)) for v in contact]

    if idx_contact is not None:
        score += 2.0 * std[:, idx_contact]
        # Premia las zonas informativas, no solo 0 o 100.
        score += 0.35 * np.exp(-((contact - 0.50) / 0.25) ** 2)
        score += 0.15 * np.exp(-((contact - 0.90) / 0.12) ** 2)
    if idx_forward is not None:
        score += 0.6 * std[:, idx_forward]
    if idx_theta_mean is not None:
        score += 0.05 * std[:, idx_theta_mean]
    if idx_theta_sig is not None:
        score += 0.08 * std[:, idx_theta_sig]
    if idx_resid is not None:
        score += 0.30 * std[:, idx_resid]
    if viability_mean is not None:
        viability = np.clip(viability_mean, 0.0, 1.0)
        # Esta es la pieza de eficiencia: pedir puntos donde la frontera
        # pasa/no-pasa es incierta, o donde clasificador y regresor discrepan.
        viability_edge = np.exp(-((viability - 0.50) / 0.22) ** 2)
        disagreement = np.abs(contact - viability)
        gate = 0.20 + 0.80 * viability
        score = gate * score + 0.90 * viability_edge + 0.70 * disagreement
        if viability_std is not None:
            score += 0.80 * viability_std
    return score, bins


def select_by_quota(
    candidates: list[dict[str, float]],
    scores: np.ndarray,
    bins: list[str],
    batch_size: int,
    seen: set[tuple[float, ...]],
    voltage_names: list[str],
    round_v: float,
) -> list[tuple[str, float, dict[str, float]]]:
    order = np.argsort(-scores)
    selected: list[tuple[str, float, dict[str, float]]] = []
    used_idx: set[int] = set()
    used_keys: set[tuple[float, ...]] = set()
    quotas = {name: max(1, int(round(frac * batch_size))) for name, frac in BIN_QUOTAS.items()}

    for bin_name, quota in quotas.items():
        for idx in order:
            i = int(idx)
            if i in used_idx or bins[i] != bin_name:
                continue
            key = key_for(voltage_names, candidates[i], round_v)
            if key in seen or key in used_keys:
                continue
            selected.append((bin_name, float(scores[i]), candidates[i]))
            used_idx.add(i)
            used_keys.add(key)
            if sum(1 for item in selected if item[0] == bin_name) >= quota:
                break

    for idx in order:
        if len(selected) >= batch_size:
            break
        i = int(idx)
        if i in used_idx:
            continue
        key = key_for(voltage_names, candidates[i], round_v)
        if key in seen or key in used_keys:
            continue
        selected.append((bins[i], float(scores[i]), candidates[i]))
        used_idx.add(i)
        used_keys.add(key)
    return selected[:batch_size]


def make_initial_batch(
    sampler: CandidateSampler,
    n: int,
    seen: set[tuple[float, ...]],
    round_v: float,
    include_elites: bool,
    olhs_fraction: float,
    olhs_restarts: int,
) -> list[tuple[str, float, dict[str, float]]]:
    selected: list[tuple[str, float, dict[str, float]]] = []
    used: set[tuple[float, ...]] = set()
    if include_elites:
        for elite in sampler.elites:
            free = sampler.clip(elite)
            key = key_for(sampler.voltage_names, free, round_v)
            if key not in seen and key not in used:
                selected.append(("seed_elite", 0.0, free))
                used.add(key)
            if len(selected) >= n:
                return selected
    olhs_n = max(0, min(n - len(selected), int(round(float(olhs_fraction) * n))))
    if olhs_n > 0:
        for free in olhs_points(
            olhs_n * 4,
            sampler.voltage_names,
            sampler.bounds,
            sampler.rng,
            restarts=olhs_restarts,
        ):
            free = sampler.clip(free)
            key = key_for(sampler.voltage_names, free, round_v)
            if key in seen or key in used:
                continue
            selected.append(("initial_olhs", 0.0, free))
            used.add(key)
            if sum(1 for mode, _, _ in selected if mode == "initial_olhs") >= olhs_n:
                break
            if len(selected) >= n:
                return selected
    attempts = 0
    while len(selected) < n:
        attempts += 1
        if attempts > n * 500:
            raise RuntimeError("No pude generar lote inicial único.")
        mode, free = sampler.sample()
        key = key_for(sampler.voltage_names, free, round_v)
        if key in seen or key in used:
            continue
        selected.append((mode, 0.0, free))
        used.add(key)
    return selected


def make_active_batch(
    sampler: CandidateSampler,
    loaded_models: list[tuple[torch.nn.Module, dict[str, Any]]],
    viability_models: list[tuple[torch.nn.Module, dict[str, Any]]],
    n: int,
    pool_size: int,
    seen: set[tuple[float, ...]],
    round_v: float,
) -> list[tuple[str, float, dict[str, float]]]:
    candidates: list[dict[str, float]] = []
    attempts = 0
    while len(candidates) < pool_size:
        attempts += 1
        if attempts > pool_size * 100:
            break
        _, free = sampler.sample()
        key = key_for(sampler.voltage_names, free, round_v)
        if key in seen:
            continue
        candidates.append(free)
    if not candidates:
        return []
    mean, std, names = predict_pool(loaded_models, candidates)
    viability_mean, viability_std = predict_viability_pool(viability_models, candidates)
    scores, bins = pool_score(mean, std, names, viability_mean, viability_std)
    return select_by_quota(
        candidates,
        scores,
        bins,
        n,
        seen,
        sampler.voltage_names,
        round_v,
    )


def run_simion_point(
    simion_cfg: dict[str, Any],
    dt_cfg: dict[str, Any],
    free: dict[str, float],
    sample_mode: str,
    score: float,
    cycle: int,
    index: int,
) -> dict[str, Any]:
    full_voltages = full_voltage_vector(dt_cfg, free)
    row: dict[str, Any] = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "budget_index": index,
        "cycle": cycle,
        "sample_mode": sample_mode,
        "candidate_score": score,
    }
    row.update({name: free[name] for name in dt_cfg["voltage_names"]})
    try:
        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltages)
        row["elapsed_seconds"] = metadata.get("elapsed_seconds")
        row.update(flatten_metrics(metrics))
    except Exception as exc:  # noqa: BLE001 - unattended run should persist failure and continue.
        row["simion_error"] = f"{type(exc).__name__}: {exc}"
    return row


def summarize_dataset(path: Path) -> dict[str, Any]:
    rows = read_rows(path)
    contacts = []
    for row in rows:
        value = contact_from_row(row)
        if value is not None and math.isfinite(value):
            contacts.append(value)
    return {
        "rows": len(rows),
        "valid_contacts": len(contacts),
        "best_contact": None if not contacts else max(contacts),
        "mean_contact": None if not contacts else float(np.mean(contacts)),
        "nonzero_contacts": int(sum(1 for v in contacts if v > 0.0)),
        "high_contacts": int(sum(1 for v in contacts if v >= 0.80)),
    }


def append_log(run_dir: Path, text: str) -> None:
    log_path = run_dir / "run.log"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(text.rstrip() + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Loop autónomo: seleccionar puntos, correr SIMION, entrenar snapshots del DT."
    )
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--run-dir", type=Path, default=None)
    parser.add_argument("--budget", type=int, default=500)
    parser.add_argument("--batch-size", type=int, default=50)
    parser.add_argument("--pool-size", type=int, default=6000)
    parser.add_argument("--seed", type=int, default=20260704)
    parser.add_argument("--ensemble-size", type=int, default=3)
    parser.add_argument("--epochs", type=int, default=400)
    parser.add_argument("--viability-epochs", type=int, default=250)
    parser.add_argument("--viability-threshold", type=float, default=0.02)
    parser.add_argument("--disable-viability", action="store_true")
    parser.add_argument("--min-train-rows", type=int, default=40)
    parser.add_argument("--max-failures", type=int, default=30)
    parser.add_argument("--no-seed-elites", action="store_true")
    parser.add_argument("--initial-olhs-fraction", type=float, default=0.20)
    parser.add_argument("--olhs-restarts", type=int, default=64)
    parser.add_argument("--dry-run", action="store_true", help="Solo diseña lotes; no corre SIMION ni entrena.")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    run_dir = (
        (ROOT / "dt" / "data" / "budget_simion" / f"run_{now_slug()}")
        if args.run_dir is None
        else (ROOT / args.run_dir if not args.run_dir.is_absolute() else args.run_dir)
    ).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    dataset_path = run_dir / "dataset.csv"
    state_path = run_dir / "state.json"
    summary_path = run_dir / "summary.json"

    simion_cfg = load_config(ROOT / str(dt_cfg["base_simion_config"]))
    simion_cfg["voltage_bounds"] = dt_cfg["full_bounds"]
    simion_cfg["fixed_voltages"] = dt_cfg["fixed_voltages"]
    simion_cfg["optimized_electrodes"] = [int(name[1:]) for name in voltage_names]

    seed = int(args.seed)
    sampler = CandidateSampler(dt_cfg, seed)
    round_v = float(dt_cfg["sampling"].get("dedupe_round_v", 0.0))
    seen = existing_keys(dataset_path, voltage_names, round_v)
    valid_rows = count_valid_rows(dataset_path, voltage_names)
    failures = 0
    cycle = 0
    latest_model = latest_model_dir(run_dir)
    latest_viability = latest_viability_dir(run_dir)

    write_json(
        run_dir / "run_config.json",
        {
            "created_or_resumed_at": datetime.now().isoformat(timespec="seconds"),
            "config": str(args.config.resolve()),
            "budget": int(args.budget),
            "batch_size": int(args.batch_size),
            "pool_size": int(args.pool_size),
            "seed": seed,
            "ensemble_size": int(args.ensemble_size),
            "epochs": int(args.epochs),
            "viability_epochs": int(args.viability_epochs),
            "viability_threshold": float(args.viability_threshold),
            "disable_viability": bool(args.disable_viability),
            "initial_olhs_fraction": float(args.initial_olhs_fraction),
            "olhs_restarts": int(args.olhs_restarts),
            "dataset_path": str(dataset_path),
            "note": "Dataset separado y fusionable; selección activa basada solo en datos de esta corrida.",
        },
    )

    print(f"Corrida: {run_dir}")
    print(f"Dataset: {dataset_path}")
    print(f"Presupuesto objetivo: {args.budget} simulaciones válidas")
    append_log(run_dir, f"START budget={args.budget} batch={args.batch_size} seed={seed}")

    while valid_rows < int(args.budget):
        cycle += 1
        remaining = int(args.budget) - valid_rows
        batch_n = min(int(args.batch_size), remaining)

        if latest_model is not None and valid_rows >= int(args.min_train_rows):
            loaded = load_ensemble(latest_model)
            viability_loaded = [] if args.disable_viability else load_viability_ensemble(latest_viability)
            batch = make_active_batch(
                sampler,
                loaded,
                viability_loaded,
                batch_n,
                int(args.pool_size),
                seen,
                round_v,
            )
            vtag = "no_viability" if not viability_loaded else latest_viability.name
            policy = f"active:{latest_model.name}:{vtag}"
        else:
            batch = make_initial_batch(
                sampler,
                batch_n,
                seen,
                round_v,
                include_elites=not args.no_seed_elites,
                olhs_fraction=float(args.initial_olhs_fraction),
                olhs_restarts=int(args.olhs_restarts),
            )
            policy = "initial_mixed"

        if not batch:
            raise RuntimeError("No pude seleccionar nuevos candidatos únicos.")

        print(f"Ciclo {cycle}: {policy}; seleccionados={len(batch)}; válidos={valid_rows}")
        append_log(run_dir, f"CYCLE {cycle} policy={policy} selected={len(batch)} valid_before={valid_rows}")

        if args.dry_run:
            for mode, score, free in batch:
                print(f"DRY {mode} score={score:.4g} " + " ".join(f"{k}={free[k]:.6g}" for k in voltage_names))
            break

        for mode, score, free in batch:
            index = valid_rows + 1
            row = run_simion_point(simion_cfg, dt_cfg, free, mode, score, cycle, index)
            append_row(dataset_path, row)
            key = key_for(voltage_names, free, round_v)
            seen.add(key)
            if row.get("simion_error"):
                failures += 1
                print(f"{index:04d} ERROR {row['simion_error']}")
                append_log(run_dir, f"ERROR index={index} {row['simion_error']}")
                if failures >= int(args.max_failures):
                    raise RuntimeError(f"Demasiados fallos SIMION consecutivos/acumulados: {failures}")
                continue
            failures = 0
            valid_rows += 1
            contact = contact_from_row({k: str(v) for k, v in row.items()})
            theta = row.get("detector_contact_angle_theta_mean_deg")
            sig = row.get("detector_contact_angle_theta_sigma_deg")
            print(
                f"{valid_rows:04d}/{args.budget} {mode} "
                f"active={100.0 * float(contact or 0.0):.2f}% "
                f"theta={'' if theta is None else f'{float(theta):.3f}'} "
                f"sig={'' if sig is None else f'{float(sig):.3f}'}"
            )

        if valid_rows >= int(args.min_train_rows):
            latest_model = run_dir / "models" / f"model_after_{valid_rows:04d}"
            print(f"Entrenando snapshot {latest_model.name} con {valid_rows} filas...")
            summary = train_snapshot(
                run_dir,
                dataset_path,
                latest_model,
                int(args.ensemble_size),
                int(args.epochs),
            )
            print(f"Snapshot listo: {latest_model}")
            append_log(run_dir, f"TRAIN rows={valid_rows} model={latest_model}")
            viability_summary = None
            if not args.disable_viability:
                latest_viability = run_dir / "models" / f"viability_after_{valid_rows:04d}"
                print(f"Entrenando clasificador de viabilidad {latest_viability.name}...")
                viability_summary = train_viability_snapshot(
                    run_dir,
                    dataset_path,
                    latest_viability,
                    int(args.ensemble_size),
                    int(args.viability_epochs),
                    float(args.viability_threshold),
                )
                print(f"Viabilidad lista: {latest_viability}")
                append_log(run_dir, f"TRAIN_VIABILITY rows={valid_rows} model={latest_viability}")
        else:
            summary = None
            viability_summary = None

        dataset_summary = summarize_dataset(dataset_path)
        state = {
            "updated_at": datetime.now().isoformat(timespec="seconds"),
            "run_dir": str(run_dir),
            "dataset_path": str(dataset_path),
            "valid_rows": int(valid_rows),
            "budget": int(args.budget),
            "cycle": int(cycle),
            "latest_model_dir": None if latest_model is None else str(latest_model),
            "latest_viability_dir": None if latest_viability is None else str(latest_viability),
            "dataset_summary": dataset_summary,
            "last_training_summary": summary,
            "last_viability_summary": viability_summary,
        }
        write_json(state_path, state)
        write_json(summary_path, dataset_summary)

    print("Terminado.")
    print(f"Dataset final: {dataset_path}")
    print(f"Estado: {state_path}")
    print(f"Resumen: {summary_path}")


if __name__ == "__main__":
    main()
