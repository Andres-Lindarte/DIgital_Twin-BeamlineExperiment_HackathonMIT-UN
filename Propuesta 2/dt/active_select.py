from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
import torch
from torch import nn

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
)
from dt.derived_metrics import add_predicted_derived_metrics  # noqa: E402
from dt.predict_dt import inverse_transform, load_model  # noqa: E402


class ViabilityMLP(nn.Module):
    def __init__(self, n_in: int, hidden: list[int], dropout: float):
        super().__init__()
        layers: list[nn.Module] = []
        last = n_in
        for width in hidden:
            layers.append(nn.Linear(last, int(width)))
            layers.append(nn.GELU())
            if dropout > 0:
                layers.append(nn.Dropout(float(dropout)))
            last = int(width)
        layers.append(nn.Linear(last, 1))
        self.net = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_ensemble(model_dir: Path):
    models = []
    ckpt0 = None
    for model_path in sorted(model_dir.glob("model_seed_*.pt")):
        model, ckpt = load_model(model_path)
        models.append((model, ckpt))
        ckpt0 = ckpt if ckpt0 is None else ckpt0
    if not models:
        raise FileNotFoundError(f"No encontré modelos en {model_dir}")
    return models, ckpt0


def load_viability_ensemble(model_dir: Path):
    models = []
    for model_path in sorted(model_dir.glob("viability_seed_*.pt")):
        ckpt = torch.load(model_path, map_location="cpu", weights_only=False)
        model = ViabilityMLP(
            len(ckpt["input_names"]),
            [int(v) for v in ckpt["hidden_layers"]],
            float(ckpt.get("dropout", 0.0)),
        )
        model.load_state_dict(ckpt["state_dict"])
        model.eval()
        models.append((model, ckpt))
    return models


def predict_ensemble(models, free: dict[str, float]) -> tuple[np.ndarray, np.ndarray, list[str]]:
    preds = []
    target_names: list[str] | None = None
    for model, ckpt in models:
        input_names = [str(v) for v in ckpt["input_names"]]
        target_names = [str(v) for v in ckpt["target_names"]]
        x = np.asarray([[free[name] for name in input_names]], dtype=np.float32)
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            y_norm = model(torch.from_numpy(x_norm)).numpy()
        y_fit = y_norm * ckpt["y_std"] + ckpt["y_mean"]
        y = inverse_transform(y_fit, target_names, str(ckpt.get("target_transform", "identity")))
        preds.append(y[0])
    arr = np.vstack(preds)
    return arr.mean(axis=0), arr.std(axis=0), target_names or []


def predict_viability(models, free: dict[str, float]) -> tuple[float | None, float | None]:
    if not models:
        return None, None
    probs = []
    for model, ckpt in models:
        input_names = [str(v) for v in ckpt["input_names"]]
        x = np.asarray([[free[name] for name in input_names]], dtype=np.float32)
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            prob = torch.sigmoid(model(torch.from_numpy(x_norm))).numpy()[0]
        probs.append(float(prob))
    arr = np.asarray(probs, dtype=np.float32)
    return float(arr.mean()), float(arr.std())


def acquisition_score(
    mean: np.ndarray,
    std: np.ndarray,
    target_names: list[str],
    viability_prob: float | None = None,
    viability_unc: float | None = None,
) -> float:
    idx = {name: i for i, name in enumerate(target_names)}
    contact_name = "detector_active_contact_fraction" if "detector_active_contact_fraction" in idx else "detector_contact_fraction"
    contact = max(0.0, min(1.0, float(mean[idx[contact_name]])))
    contact_std = float(std[idx[contact_name]])
    if "detector_contact_angle_theta_sigma_deg" in idx:
        angle_quality = float(mean[idx["detector_contact_angle_theta_sigma_deg"]])
        angle_unc = float(std[idx["detector_contact_angle_theta_sigma_deg"]])
    elif "terminal_angle_theta_p95_deg" in idx:
        angle_quality = float(mean[idx["terminal_angle_theta_p95_deg"]])
        angle_unc = float(std[idx["terminal_angle_theta_p95_deg"]])
        if "terminal_angle_theta_p99_deg" in idx:
            angle_unc += float(std[idx["terminal_angle_theta_p99_deg"]])
    else:
        angle_quality = 0.0
        angle_unc = 0.0

    # Interés de borde: máximo cerca de 50%, todavía útil en 10-90%.
    transition = math.exp(-((contact - 0.50) / 0.28) ** 2)
    high_contact_uncertain_angle = max(contact, 0.0) * min(angle_unc / 8.0, 1.5)
    good_but_uncertain = max(contact - 0.75, 0.0) * min(contact_std * 8.0, 1.0)
    low_angle_elite_probe = max(contact - 0.90, 0.0) * math.exp(-max(angle_quality, 0.0) / 8.0)
    if viability_prob is None:
        viability_prob = 1.0
    if viability_unc is None:
        viability_unc = 0.0
    # Aprende bordes útiles: máxima señal cuando la viabilidad está cerca de 0.5
    # o cuando el clasificador/regresor discrepan.
    viability_edge = math.exp(-((viability_prob - 0.50) / 0.22) ** 2)
    viable_regressor_disagreement = abs(max(contact, 0.0) - viability_prob)
    viable_gate = 0.15 + 0.85 * max(0.0, min(1.0, viability_prob))
    return (
        viable_gate
        * (
            1.8 * contact_std
            + 0.9 * transition
            + 0.7 * high_contact_uncertain_angle
            + 0.4 * good_but_uncertain
            + 0.2 * low_angle_elite_probe
        )
        + 0.9 * viability_edge
        + 0.8 * viability_unc
        + 0.7 * viable_regressor_disagreement
    )


def write_candidates(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        return
    header = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)


def append_failure(path: Path, row: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.is_file() and path.stat().st_size > 0
    header = list(row.keys())
    if exists:
        with path.open("r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            old_header = list(reader.fieldnames or [])
        for key in old_header:
            if key not in header:
                header.insert(0, key)
        for key in row.keys():
            if key not in header:
                header.append(key)
    with path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
        if not exists:
            writer.writeheader()
        writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Selecciona nuevos puntos SIMION usando incertidumbre del DT.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--model-dir", type=Path, default=ROOT / "dt" / "models" / "baseline_mlp")
    parser.add_argument("--pool", type=int, default=5000, help="Candidatos baratos a evaluar con el DT.")
    parser.add_argument("--select", type=int, default=100, help="Puntos elegidos.")
    parser.add_argument("--seed", type=int, default=20260629)
    parser.add_argument("--out", type=Path, default=ROOT / "dt" / "data" / "active_candidates.csv")
    parser.add_argument("--run-simion", action="store_true", help="Corre SIMION en los puntos seleccionados.")
    parser.add_argument("--max-failures", type=int, default=10)
    parser.add_argument("--timeout-seconds", type=float, default=180.0)
    parser.add_argument("--viability-model-dir", type=Path, default=ROOT / "dt" / "models" / "viability_mlp")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    data_path = (ROOT / str(dt_cfg["output_dataset"])).resolve()
    models, _ = load_ensemble(args.model_dir.resolve())
    viability_models = load_viability_ensemble(args.viability_model_dir.resolve())
    sampler = CandidateSampler(dt_cfg, args.seed)
    round_v = float(dt_cfg["sampling"].get("dedupe_round_v", 0.0))
    seen = existing_keys(data_path, sampler.voltage_names, round_v)
    candidate_rows: list[dict[str, Any]] = []
    attempts = 0
    while len(candidate_rows) < args.pool:
        attempts += 1
        if attempts > args.pool * 50:
            break
        mode, free = sampler.sample()
        key = key_for(sampler.voltage_names, free, round_v)
        if key in seen:
            continue
        seen.add(key)
        mean, std, target_names = predict_ensemble(models, free)
        viability_prob, viability_unc = predict_viability(viability_models, free)
        score = acquisition_score(mean, std, target_names, viability_prob, viability_unc)
        row: dict[str, Any] = {
            "score": score,
            "sample_mode": mode,
            **{name: free[name] for name in sampler.voltage_names},
        }
        if viability_prob is not None:
            row["pred_viability_prob"] = viability_prob
        if viability_unc is not None:
            row["unc_viability_prob"] = viability_unc
        for name, value, sigma in zip(target_names, mean, std):
            row[f"pred_{name}"] = float(value)
            row[f"unc_{name}"] = float(sigma)
        add_predicted_derived_metrics(row)
        candidate_rows.append(row)

    candidate_rows.sort(key=lambda r: float(r["score"]), reverse=True)
    selected = candidate_rows[: args.select]
    write_candidates(args.out.resolve(), selected)
    print(f"Seleccionados {len(selected)} de {len(candidate_rows)} candidatos -> {args.out}")
    for row in selected[: min(10, len(selected))]:
        print(
            f"score={float(row['score']):.4f} "
            f"contact={100*float(row.get('pred_detector_active_contact_fraction', row.get('pred_detector_contact_fraction', 0.0))):.1f}% "
            f"unc={float(row.get('unc_detector_active_contact_fraction', row.get('unc_detector_contact_fraction', 0.0))):.3f} "
            f"viab={float(row.get('pred_viability_prob', 1.0)):.3f} "
            f"angle={float(row.get('pred_detector_contact_angle_theta_sigma_deg', row.get('pred_terminal_angle_theta_p95_deg', 0.0))):.2f} "
            + " ".join(f"{name}={float(row[name]):.6g}" for name in sampler.voltage_names)
        )

    if not args.run_simion:
        return

    failure_path = ROOT / "dt" / "data" / "active_failures.csv"
    simion_cfg = load_config(ROOT / str(dt_cfg["base_simion_config"]))
    simion_cfg["voltage_bounds"] = dt_cfg["full_bounds"]
    simion_cfg["fixed_voltages"] = dt_cfg["fixed_voltages"]
    simion_cfg["optimized_electrodes"] = [int(name[1:]) for name in dt_cfg["voltage_names"]]
    # En ciclos activos es mejor tolerar corridas lentas: si un punto cuelga, se
    # registra como fallo y el resto del lote sigue vivo.
    simion_cfg["timeout_seconds"] = float(args.timeout_seconds)
    failures = 0
    for i, row in enumerate(selected, start=1):
        free = {name: float(row[name]) for name in sampler.voltage_names}
        try:
            metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltage_vector(dt_cfg, free))
        except Exception as exc:
            failures += 1
            fail_row: dict[str, Any] = {
                "timestamp": datetime.now().isoformat(timespec="seconds"),
                "sample_mode": "active_select_failed",
                "active_score": row["score"],
                "error_type": type(exc).__name__,
                "error": str(exc)[-1000:],
            }
            fail_row.update(free)
            append_failure(failure_path, fail_row)
            print(
                f"{i:04d}/{len(selected)} active FALLÓ "
                f"{type(exc).__name__}: {str(exc)[-180:]}"
            )
            if failures >= args.max_failures:
                raise RuntimeError(
                    f"Demasiadas corridas fallidas ({failures}). "
                    f"Últimos fallos en {failure_path}"
                ) from exc
            continue
        out_row: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "sample_mode": "active_select",
            "elapsed_seconds": metadata.get("elapsed_seconds"),
            "active_score": row["score"],
        }
        out_row.update(free)
        out_row.update(flatten_metrics(metrics))
        append_row(data_path, out_row)
        contact = float(metrics.get("detector_active_contact_fraction") or metrics.get("transmission") or 0.0)
        theta_sig = float(metrics.get("detector_contact_angle_theta_sigma_deg") or 0.0)
        print(f"{i:04d}/{len(selected)} active contact={100*contact:.2f}% theta_sig={theta_sig:.3f}")


if __name__ == "__main__":
    main()
