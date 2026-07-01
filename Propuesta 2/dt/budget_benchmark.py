from __future__ import annotations

import argparse
import csv
import json
import math
import random
import shutil
import sys
from pathlib import Path
from typing import Any

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dt.derived_metrics import add_predicted_derived_metrics, residual_from_row  # noqa: E402
from dt.predict_dt import inverse_transform, load_model  # noqa: E402
from dt.train_dt import load_table, train_one  # noqa: E402


ACTIVE_BINS = [
    ("zero", 0.00, 0.01),
    ("low", 0.01, 0.10),
    ("signal_low", 0.10, 0.40),
    ("signal_mid", 0.40, 0.80),
    ("signal_high", 0.80, 0.98),
    ("elite", 0.98, 1.01),
]


SELECT_QUOTAS = [
    ("zero", 0.08),
    ("low", 0.10),
    ("signal_low", 0.20),
    ("signal_mid", 0.25),
    ("signal_high", 0.17),
    ("elite", 0.20),
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def row_float(row: dict[str, str], key: str, default: float = 0.0) -> float:
    try:
        return float(row.get(key, default) or default)
    except (TypeError, ValueError):
        return default


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row.keys():
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def active_bin(row: dict[str, str]) -> str:
    active = row_float(row, "detector_active_contact_fraction", row_float(row, "transmission"))
    for label, lo, hi in ACTIVE_BINS:
        if lo <= active < hi:
            return label
    return "other"


def stratified_split(
    rows: list[dict[str, str]],
    holdout_fraction: float,
    seed: int,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    rng = random.Random(seed)
    by_bin: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        by_bin.setdefault(active_bin(row), []).append(row)
    holdout: list[dict[str, str]] = []
    pool: list[dict[str, str]] = []
    for items in by_bin.values():
        rng.shuffle(items)
        n_hold = max(1, int(round(len(items) * holdout_fraction))) if len(items) > 10 else max(0, len(items) // 5)
        holdout.extend(items[:n_hold])
        pool.extend(items[n_hold:])
    rng.shuffle(holdout)
    rng.shuffle(pool)
    return pool, holdout


def allocate(n: int, quotas: list[tuple[str, float]]) -> dict[str, int]:
    total = sum(w for _, w in quotas)
    raw = {label: n * weight / total for label, weight in quotas}
    out = {label: int(value) for label, value in raw.items()}
    while sum(out.values()) < n:
        label = max(raw, key=lambda k: raw[k] - int(raw[k]))
        out[label] += 1
        raw[label] = int(raw[label])
    return out


def select_initial(pool: list[dict[str, str]], n: int, seed: int) -> tuple[list[int], list[int]]:
    rng = random.Random(seed)
    by_bin: dict[str, list[int]] = {}
    for idx, row in enumerate(pool):
        by_bin.setdefault(active_bin(row), []).append(idx)
    counts = allocate(n, SELECT_QUOTAS)
    selected: list[int] = []
    used: set[int] = set()
    for label, count in counts.items():
        candidates = by_bin.get(label, [])
        candidates.sort(key=lambda i: row_float(pool[i], "detector_contact_angle_theta_sigma_deg"))
        if len(candidates) <= count:
            picks = candidates
        else:
            picks = [candidates[round(j * (len(candidates) - 1) / max(1, count - 1))] for j in range(count)]
            rng.shuffle(picks)
        for idx in picks:
            if idx not in used:
                used.add(idx)
                selected.append(idx)
    if len(selected) < n:
        rest = [i for i in range(len(pool)) if i not in used]
        rng.shuffle(rest)
        selected.extend(rest[: n - len(selected)])
    selected = selected[:n]
    remaining = [i for i in range(len(pool)) if i not in set(selected)]
    return selected, remaining


def train_ensemble_for_rows(
    rows: list[dict[str, str]],
    dt_cfg: dict[str, Any],
    out_dir: Path,
    ensemble_size: int,
    epochs: int,
) -> dict[str, Any]:
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    data_path = out_dir / "train_subset.csv"
    write_rows(data_path, rows)
    input_names = [str(v) for v in dt_cfg["voltage_names"]]
    train_cfg = dict(dt_cfg["training"])
    train_cfg["ensemble_size"] = ensemble_size
    train_cfg["epochs"] = epochs
    target_names = [str(v) for v in train_cfg["targets"]]
    x, y, y_mask = load_table(data_path, input_names, target_names)
    reports = []
    for i in range(ensemble_size):
        reports.append(train_one(1000 + i, x, y, y_mask, train_cfg, out_dir, input_names, target_names))
    summary = {
        "n_rows": len(rows),
        "input_names": input_names,
        "target_names": target_names,
        "target_observed_count": {name: int((y_mask[:, j] > 0).sum()) for j, name in enumerate(target_names)},
        "models": reports,
    }
    (out_dir / "training_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return summary


def predict_rows(model_dir: Path, rows: list[dict[str, str]], voltage_names: list[str]) -> tuple[list[dict[str, float]], list[str]]:
    models = []
    target_names: list[str] | None = None
    for model_path in sorted(model_dir.glob("model_seed_*.pt")):
        model, ckpt = load_model(model_path)
        models.append((model, ckpt))
        target_names = [str(v) for v in ckpt["target_names"]]
    if not models or target_names is None:
        raise FileNotFoundError(f"No modelos en {model_dir}")
    out: list[dict[str, float]] = []
    for row in rows:
        preds = []
        free = {name: row_float(row, name) for name in voltage_names}
        for model, ckpt in models:
            input_names = [str(v) for v in ckpt["input_names"]]
            x = np.asarray([[free[name] for name in input_names]], dtype=np.float32)
            x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
            with torch.no_grad():
                y_norm = model(torch.from_numpy(x_norm)).numpy()
            y_fit = y_norm * ckpt["y_std"] + ckpt["y_mean"]
            y = inverse_transform(y_fit, target_names, str(ckpt.get("target_transform", "identity")))
            preds.append(y[0])
        arr = np.vstack(preds)
        mean = {f"pred_{name}": float(v) for name, v in zip(target_names, arr.mean(axis=0))}
        unc = {f"unc_{name}": float(v) for name, v in zip(target_names, arr.std(axis=0))}
        add_predicted_derived_metrics(mean)
        mean.update(unc)
        out.append(mean)
    return out, target_names


def true_targets(row: dict[str, str], target_names: list[str]) -> dict[str, float | None]:
    out: dict[str, float | None] = {}
    for name in target_names:
        if name == "derived_vz_sigma_residual":
            out[name] = residual_from_row(row)
        else:
            out[name] = row_float(row, name)
    return out


def evaluate(model_dir: Path, rows: list[dict[str, str]], dt_cfg: dict[str, Any]) -> dict[str, Any]:
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    pred_rows, target_names = predict_rows(model_dir, rows, voltage_names)
    metrics: dict[str, Any] = {"n_eval": len(rows)}
    bins: dict[str, list[int]] = {}
    for i, row in enumerate(rows):
        bins.setdefault(active_bin(row), []).append(i)

    def mae_for(indices: list[int], target: str, pred_key: str | None = None) -> float | None:
        pred_key = pred_key or f"pred_{target}"
        vals = []
        for idx in indices:
            truth = true_targets(rows[idx], target_names).get(target)
            if truth is None:
                continue
            pred = pred_rows[idx].get(pred_key)
            if pred is None:
                continue
            if target in ("detector_active_contact_fraction", "detector_active_forward_fraction"):
                pred = max(0.0, min(1.0, pred))
            elif "theta" in target or "sigma" in target:
                pred = max(0.0, pred)
            vals.append(abs(float(pred) - float(truth)))
        return None if not vals else float(sum(vals) / len(vals))

    all_idx = list(range(len(rows)))
    high_idx = [i for i, row in enumerate(rows) if row_float(row, "detector_active_contact_fraction") >= 0.80]
    informative_idx = [i for i, row in enumerate(rows) if row_float(row, "detector_active_contact_fraction") >= 0.10]
    for prefix, indices in [("all", all_idx), ("informative", informative_idx), ("high", high_idx)]:
        metrics[f"{prefix}_n"] = len(indices)
        for target in target_names:
            metrics[f"{prefix}_mae_{target}"] = mae_for(indices, target)
        # metrica final derivada, comparable con valor real de velocidad si existe.
        vals = []
        for idx in indices:
            real = row_float(rows[idx], "detector_contact_speed_vz_sigma", float("nan"))
            pred = pred_rows[idx].get("derived_vz_sigma_corrected")
            if pred is not None and math.isfinite(real):
                vals.append(abs(max(0.0, float(pred)) - real))
        metrics[f"{prefix}_mae_vz_sigma_corrected"] = None if not vals else float(sum(vals) / len(vals))

    # Honestidad: correlacion simple error active vs incertidumbre active.
    errors = []
    uncs = []
    for idx, row in enumerate(rows):
        pred = max(0.0, min(1.0, pred_rows[idx].get("pred_detector_active_contact_fraction", 0.0)))
        errors.append(abs(pred - row_float(row, "detector_active_contact_fraction")))
        uncs.append(pred_rows[idx].get("unc_detector_active_contact_fraction", 0.0))
    if len(errors) > 3 and np.std(uncs) > 1e-12:
        metrics["active_error_unc_corr"] = float(np.corrcoef(np.asarray(errors), np.asarray(uncs))[0, 1])
    else:
        metrics["active_error_unc_corr"] = None
    return metrics


def acquisition_scores(model_dir: Path, rows: list[dict[str, str]], dt_cfg: dict[str, Any]) -> list[float]:
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    pred_rows, _targets = predict_rows(model_dir, rows, voltage_names)
    scores = []
    for pred in pred_rows:
        active = max(0.0, min(1.0, pred.get("pred_detector_active_contact_fraction", 0.0)))
        u_active = max(0.0, pred.get("unc_detector_active_contact_fraction", 0.0))
        u_theta = max(0.0, pred.get("unc_detector_contact_angle_theta_sigma_deg", 0.0))
        u_res = max(0.0, pred.get("unc_derived_vz_sigma_residual", 0.0))
        # Mezcla: incertidumbre + interes por region informativa, evitando que todo sea cero.
        informative = math.exp(-((active - 0.55) / 0.35) ** 2)
        high = math.exp(-((active - 0.92) / 0.18) ** 2)
        score = 1.6 * u_active + 0.35 * min(u_theta, 5.0) + 0.6 * u_res + 0.35 * informative + 0.25 * high
        scores.append(float(score))
    return scores


def select_next_active(
    model_dir: Path,
    pool: list[dict[str, str]],
    pool_indices: list[int],
    dt_cfg: dict[str, Any],
    n: int,
) -> tuple[list[int], list[int]]:
    if n <= 0 or not pool_indices:
        return [], pool_indices
    candidates = [pool[i] for i in pool_indices]
    scores = acquisition_scores(model_dir, candidates, dt_cfg)
    by_pred_bin: dict[str, list[tuple[float, int]]] = {label: [] for label, _ in SELECT_QUOTAS}
    # Bin por prediccion si existe; fallback al bin verdadero solo para balance de benchmark.
    preds, _ = predict_rows(model_dir, candidates, [str(v) for v in dt_cfg["voltage_names"]])
    for local_i, global_i in enumerate(pool_indices):
        active_pred = max(0.0, min(1.0, preds[local_i].get("pred_detector_active_contact_fraction", 0.0)))
        label = "zero"
        for b_label, lo, hi in ACTIVE_BINS:
            if lo <= active_pred < hi:
                label = b_label
                break
        if label not in by_pred_bin:
            label = active_bin(pool[global_i])
        by_pred_bin.setdefault(label, []).append((scores[local_i], global_i))

    counts = allocate(n, SELECT_QUOTAS)
    selected: list[int] = []
    used: set[int] = set()
    for label, count in counts.items():
        items = sorted(by_pred_bin.get(label, []), reverse=True)
        for _score, idx in items[:count]:
            if idx not in used:
                selected.append(idx)
                used.add(idx)
    if len(selected) < n:
        rest = sorted(((scores[i], pool_indices[i]) for i in range(len(pool_indices)) if pool_indices[i] not in used), reverse=True)
        for _score, idx in rest[: n - len(selected)]:
            selected.append(idx)
            used.add(idx)
    remaining = [idx for idx in pool_indices if idx not in used]
    return selected[:n], remaining


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Benchmark presupuestado reproducible usando dataset completo como oraculo."
    )
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--data", type=Path, default=None)
    parser.add_argument("--budget", type=int, default=1500)
    parser.add_argument("--initial", type=int, default=80)
    parser.add_argument("--batch-size", type=int, default=100)
    parser.add_argument("--milestones", type=str, default="80,150,300,500,800,1000,1200,1500")
    parser.add_argument("--holdout-fraction", type=float, default=0.20)
    parser.add_argument("--seed", type=int, default=20260703)
    parser.add_argument("--ensemble-size", type=int, default=3)
    parser.add_argument("--epochs", type=int, default=400)
    parser.add_argument("--out-dir", type=Path, default=ROOT / "dt" / "models" / "budget_benchmark")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    dt_cfg = json.loads(args.config.resolve().read_text(encoding="utf-8"))
    data_path = (ROOT / str(args.data or dt_cfg["output_dataset"])).resolve()
    rows = read_rows(data_path)
    pool, holdout = stratified_split(rows, args.holdout_fraction, args.seed)
    milestones = sorted({m for m in [int(x) for x in args.milestones.split(",") if x.strip()] if m <= args.budget})
    if args.budget not in milestones:
        milestones.append(args.budget)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_rows(args.out_dir / "holdout.csv", holdout)

    selected, remaining = select_initial(pool, min(args.initial, args.budget), args.seed)
    results: list[dict[str, Any]] = []

    print(
        f"Dataset={len(rows)} pool={len(pool)} holdout={len(holdout)} "
        f"budget={args.budget} initial={len(selected)} seed={args.seed}",
        flush=True,
    )

    for milestone in milestones:
        while len(selected) < milestone:
            # Entrena modelo temporal para escoger siguiente batch por incertidumbre.
            current_rows = [pool[i] for i in selected]
            select_model_dir = args.out_dir / "_selector_model"
            train_ensemble_for_rows(
                current_rows,
                dt_cfg,
                select_model_dir,
                ensemble_size=max(2, min(args.ensemble_size, 3)),
                epochs=max(80, min(args.epochs, 250)),
            )
            need = min(args.batch_size, milestone - len(selected))
            new_ids, remaining = select_next_active(select_model_dir, pool, remaining, dt_cfg, need)
            if not new_ids:
                print("No quedan puntos para seleccionar.")
                break
            selected.extend(new_ids)
            print(f"  seleccionado hasta {len(selected)}/{milestone}", flush=True)

        train_rows = [pool[i] for i in selected[:milestone]]
        model_dir = args.out_dir / f"model_budget_{milestone:04d}"
        print(f"\n=== Entrenando/evaluando presupuesto {milestone} con {len(train_rows)} puntos ===", flush=True)
        train_summary = train_ensemble_for_rows(train_rows, dt_cfg, model_dir, args.ensemble_size, args.epochs)
        metrics = evaluate(model_dir, holdout, dt_cfg)
        row = {
            "budget": milestone,
            "n_train": len(train_rows),
            "n_holdout": len(holdout),
            "target_observed_count": train_summary.get("target_observed_count"),
            **metrics,
        }
        results.append(row)
        (args.out_dir / "summary.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
        # CSV compacto acumulado.
        compact_keys = [
            "budget",
            "n_train",
            "all_mae_detector_active_contact_fraction",
            "informative_mae_detector_active_contact_fraction",
            "high_mae_detector_active_contact_fraction",
            "all_mae_detector_contact_angle_theta_sigma_deg",
            "informative_mae_detector_contact_angle_theta_sigma_deg",
            "high_mae_detector_contact_angle_theta_sigma_deg",
            "all_mae_vz_sigma_corrected",
            "informative_mae_vz_sigma_corrected",
            "high_mae_vz_sigma_corrected",
            "active_error_unc_corr",
        ]
        with (args.out_dir / "summary.csv").open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=compact_keys, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(results)
        print(
            f"budget={milestone} "
            f"active_all={row.get('all_mae_detector_active_contact_fraction')} "
            f"theta_sig_high={row.get('high_mae_detector_contact_angle_theta_sigma_deg')} "
            f"vz_high={row.get('high_mae_vz_sigma_corrected')} "
            f"unc_corr={row.get('active_error_unc_corr')}",
            flush=True,
        )

    print(f"\nResumen: {args.out_dir / 'summary.csv'}")
    print(f"Detalle: {args.out_dir / 'summary.json'}")


if __name__ == "__main__":
    main()
