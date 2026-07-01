from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path
from typing import Any

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, TensorDataset

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dt.derived_metrics import residual_from_row


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_csv_numeric(path: Path) -> dict[str, list[float]]:
    import csv

    cols: dict[str, list[float]] = {}
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            for key, raw in row.items():
                if raw is None or raw == "":
                    continue
                try:
                    value = float(raw)
                except ValueError:
                    continue
                cols.setdefault(key, []).append(value)
    return cols


def target_value(row: dict[str, str], name: str) -> tuple[float, float]:
    if name == "derived_vz_sigma_residual":
        residual = residual_from_row(row)
        if residual is None:
            return 0.0, 0.0
        return float(residual), 1.0
    try:
        return float(row[name]), 1.0
    except (KeyError, TypeError, ValueError):
        return 0.0, 0.0


def load_table(path: Path, inputs: list[str], targets: list[str]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    import csv

    xs: list[list[float]] = []
    ys: list[list[float]] = []
    masks: list[list[float]] = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                x = [float(row[name]) for name in inputs]
            except (KeyError, TypeError, ValueError):
                continue
            y = []
            mask = []
            for name in targets:
                value, weight = target_value(row, name)
                y.append(value)
                mask.append(weight)
            required_ok = all(weight > 0 for name, weight in zip(targets, mask) if name != "derived_vz_sigma_residual")
            if required_ok and all(math.isfinite(v) for v in x + y):
                xs.append(x)
                ys.append(y)
                masks.append(mask)
    if not xs:
        raise ValueError(f"No hay filas completas para inputs={inputs} targets={targets} en {path}")
    return (
        np.asarray(xs, dtype=np.float32),
        np.asarray(ys, dtype=np.float32),
        np.asarray(masks, dtype=np.float32),
    )


class MLP(nn.Module):
    def __init__(self, n_in: int, n_out: int, hidden: list[int], dropout: float):
        super().__init__()
        layers: list[nn.Module] = []
        last = n_in
        for width in hidden:
            layers.append(nn.Linear(last, int(width)))
            layers.append(nn.GELU())
            if dropout > 0:
                layers.append(nn.Dropout(float(dropout)))
            last = int(width)
        layers.append(nn.Linear(last, n_out))
        self.net = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


def log_cosh_loss(pred: torch.Tensor, target: torch.Tensor) -> torch.Tensor:
    err = pred - target
    return torch.mean(torch.log(torch.cosh(torch.clamp(err, -20.0, 20.0))))


def weighted_log_cosh_loss(
    pred: torch.Tensor, target: torch.Tensor, weights: torch.Tensor
) -> torch.Tensor:
    err = pred - target
    raw = torch.log(torch.cosh(torch.clamp(err, -20.0, 20.0)))
    weighted = raw * weights
    return weighted.sum() / torch.clamp(weights.sum(), min=1.0)


def standardize(arr: np.ndarray, eps: float = 1e-8) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = arr.mean(axis=0)
    std = arr.std(axis=0)
    std = np.where(std < eps, 1.0, std)
    return (arr - mean) / std, mean.astype(np.float32), std.astype(np.float32)


def standardize_masked(
    arr: np.ndarray,
    mask: np.ndarray,
    eps: float = 1e-8,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = np.zeros(arr.shape[1], dtype=np.float32)
    std = np.ones(arr.shape[1], dtype=np.float32)
    for j in range(arr.shape[1]):
        valid = mask[:, j] > 0
        if valid.any():
            vals = arr[valid, j]
            mean[j] = float(vals.mean())
            s = float(vals.std())
            std[j] = 1.0 if s < eps else s
    return ((arr - mean) / std).astype(np.float32), mean, std


def uses_contact_angle_transform(target_names: list[str]) -> bool:
    return target_names == [
        "detector_contact_fraction",
        "terminal_angle_theta_mean_deg",
        "terminal_angle_theta_p95_deg",
        "terminal_angle_theta_p99_deg",
    ]


def transform_targets(y: np.ndarray, target_names: list[str]) -> tuple[np.ndarray, str]:
    if not uses_contact_angle_transform(target_names):
        return y.astype(np.float32), "identity"
    out = np.zeros_like(y, dtype=np.float32)
    contact = np.clip(y[:, 0], 0.0, 1.0)
    theta_mean = np.maximum(y[:, 1], 0.0)
    theta_p95 = np.maximum(y[:, 2], theta_mean)
    theta_p99 = np.maximum(y[:, 3], theta_p95)
    out[:, 0] = contact
    out[:, 1] = np.log1p(theta_mean)
    out[:, 2] = np.log1p(theta_p95 - theta_mean)
    out[:, 3] = np.log1p(theta_p99 - theta_p95)
    return out, "contact_angle_monotonic"


def inverse_transform_targets(y: np.ndarray, target_names: list[str], transform: str) -> np.ndarray:
    if transform != "contact_angle_monotonic" or not uses_contact_angle_transform(target_names):
        return y.astype(np.float32)
    out = np.zeros_like(y, dtype=np.float32)
    contact = np.clip(y[:, 0], 0.0, 1.0)
    theta_mean = np.maximum(0.0, np.expm1(y[:, 1]))
    delta_95 = np.maximum(0.0, np.expm1(y[:, 2]))
    delta_99 = np.maximum(0.0, np.expm1(y[:, 3]))
    theta_p95 = theta_mean + delta_95
    theta_p99 = theta_p95 + delta_99
    out[:, 0] = contact
    out[:, 1] = np.clip(theta_mean, 0.0, 180.0)
    out[:, 2] = np.clip(theta_p95, 0.0, 180.0)
    out[:, 3] = np.clip(theta_p99, 0.0, 180.0)
    return out


def target_weights(y_raw: np.ndarray, cfg: dict[str, Any], target_names: list[str]) -> np.ndarray:
    weights = np.ones_like(y_raw, dtype=np.float32)
    if not target_names or "contact" not in target_names[0]:
        return weights
    contact = np.clip(y_raw[:, 0], 0.0, 1.0)
    threshold = float(cfg.get("angle_loss_contact_min", 0.70))
    floor = float(cfg.get("angle_loss_floor", 0.02))
    if threshold <= 0:
        angle_weight = np.ones_like(contact, dtype=np.float32)
    else:
        angle_weight = np.clip(contact / threshold, 0.0, 1.0) ** 2
    angle_weight = np.maximum(angle_weight, floor)
    weights[:, 1:] = angle_weight[:, None]
    return weights


def masked_metric(
    values: np.ndarray,
    mask: np.ndarray,
    names: list[str],
) -> dict[str, float | None]:
    out: dict[str, float | None] = {}
    for j, name in enumerate(names):
        valid = mask[:, j] > 0
        if valid.any():
            out[name] = float(values[valid, j].mean())
        else:
            out[name] = None
    return out


def train_one(
    seed: int,
    x: np.ndarray,
    y: np.ndarray,
    y_mask: np.ndarray,
    cfg: dict[str, Any],
    model_dir: Path,
    input_names: list[str],
    target_names: list[str],
) -> dict[str, Any]:
    torch.manual_seed(seed)
    np.random.seed(seed)
    random.seed(seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    y_fit, target_transform = transform_targets(y, target_names)

    n = len(x)
    indices = np.arange(n)
    rng = np.random.default_rng(seed)
    rng.shuffle(indices)
    n_val = max(1, int(round(n * float(cfg["validation_fraction"])))) if n > 5 else max(1, n // 3)
    val_idx = indices[:n_val]
    train_idx = indices[n_val:]
    if len(train_idx) == 0:
        train_idx = val_idx

    x_norm, x_mean, x_std = standardize(x[train_idx])
    y_norm, y_mean, y_std = standardize_masked(y_fit[train_idx], y_mask[train_idx])
    x_train = ((x[train_idx] - x_mean) / x_std).astype(np.float32)
    y_train = ((y_fit[train_idx] - y_mean) / y_std).astype(np.float32)
    w_train = target_weights(y[train_idx], cfg, target_names) * y_mask[train_idx]
    x_val = ((x[val_idx] - x_mean) / x_std).astype(np.float32)
    y_val = ((y_fit[val_idx] - y_mean) / y_std).astype(np.float32)
    w_val = target_weights(y[val_idx], cfg, target_names) * y_mask[val_idx]

    model = MLP(
        n_in=x.shape[1],
        n_out=y.shape[1],
        hidden=[int(v) for v in cfg["hidden_layers"]],
        dropout=float(cfg.get("dropout", 0.0)),
    ).to(device)
    opt = torch.optim.AdamW(
        model.parameters(),
        lr=float(cfg["learning_rate"]),
        weight_decay=float(cfg["weight_decay"]),
    )
    train_ds = TensorDataset(
        torch.from_numpy(x_train), torch.from_numpy(y_train), torch.from_numpy(w_train)
    )
    train_loader = DataLoader(
        train_ds,
        batch_size=min(int(cfg["batch_size"]), max(1, len(train_ds))),
        shuffle=True,
    )
    x_val_t = torch.from_numpy(x_val).to(device)
    y_val_t = torch.from_numpy(y_val).to(device)
    w_val_t = torch.from_numpy(w_val).to(device)

    best_state = None
    best_val = float("inf")
    bad = 0
    history: list[dict[str, float]] = []
    for epoch in range(1, int(cfg["epochs"]) + 1):
        model.train()
        train_losses = []
        for xb, yb, wb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)
            wb = wb.to(device)
            pred = model(xb)
            loss = weighted_log_cosh_loss(pred, yb, wb)
            opt.zero_grad(set_to_none=True)
            loss.backward()
            opt.step()
            train_losses.append(float(loss.detach().cpu()))
        model.eval()
        with torch.no_grad():
            val_pred = model(x_val_t)
            val_loss = float(weighted_log_cosh_loss(val_pred, y_val_t, w_val_t).detach().cpu())
        history.append({"epoch": float(epoch), "train_loss": float(np.mean(train_losses)), "val_loss": val_loss})
        if val_loss < best_val - 1e-6:
            best_val = val_loss
            bad = 0
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
        else:
            bad += 1
        if bad >= int(cfg["patience"]):
            break

    if best_state is not None:
        model.load_state_dict(best_state)
    model.eval()
    with torch.no_grad():
        pred_norm = model(x_val_t).detach().cpu().numpy()
    pred_fit = pred_norm * y_std + y_mean
    pred = inverse_transform_targets(pred_fit, target_names, target_transform)
    truth = y[val_idx]
    truth_mask = y_mask[val_idx]
    abs_err = np.abs(pred - truth)
    sq_err = (pred - truth) ** 2
    mae_values = []
    rmse_values = []
    for j in range(y.shape[1]):
        valid = truth_mask[:, j] > 0
        if valid.any():
            mae_values.append(float(np.mean(abs_err[valid, j])))
            rmse_values.append(float(np.sqrt(np.mean(sq_err[valid, j]))))
        else:
            mae_values.append(float("nan"))
            rmse_values.append(float("nan"))
    mae = np.asarray(mae_values, dtype=np.float32)
    rmse = np.asarray(rmse_values, dtype=np.float32)
    high_contact_mask = truth[:, 0] >= float(cfg.get("angle_loss_contact_min", 0.70))
    if high_contact_mask.any():
        high_contact_mae_values = []
        high_contact_rmse_values = []
        for j in range(y.shape[1]):
            valid = high_contact_mask & (truth_mask[:, j] > 0)
            if valid.any():
                high_contact_mae_values.append(float(np.mean(abs_err[valid, j])))
                high_contact_rmse_values.append(float(np.sqrt(np.mean(sq_err[valid, j]))))
            else:
                high_contact_mae_values.append(float("nan"))
                high_contact_rmse_values.append(float("nan"))
        high_contact_mae_values = np.asarray(high_contact_mae_values, dtype=np.float32)
        high_contact_rmse_values = np.asarray(high_contact_rmse_values, dtype=np.float32)
    else:
        high_contact_mae_values = np.full_like(mae, np.nan)
        high_contact_rmse_values = np.full_like(rmse, np.nan)

    model_dir.mkdir(parents=True, exist_ok=True)
    model_path = model_dir / f"model_seed_{seed}.pt"
    torch.save(
        {
            "state_dict": model.state_dict(),
            "input_names": input_names,
            "target_names": target_names,
            "x_mean": x_mean,
            "x_std": x_std,
            "y_mean": y_mean,
            "y_std": y_std,
            "target_transform": target_transform,
            "angle_loss_contact_min": float(cfg.get("angle_loss_contact_min", 0.70)),
            "angle_loss_floor": float(cfg.get("angle_loss_floor", 0.02)),
            "hidden_layers": [int(v) for v in cfg["hidden_layers"]],
            "dropout": float(cfg.get("dropout", 0.0)),
        },
        model_path,
    )
    return {
        "seed": seed,
        "device": str(device),
        "epochs": len(history),
        "best_val_loss": best_val,
        "model_path": str(model_path),
        "mae": {name: float(value) for name, value in zip(target_names, mae)},
        "rmse": {name: float(value) for name, value in zip(target_names, rmse)},
        "high_contact_count": int(high_contact_mask.sum()),
        "target_observed_count": {
            name: int((y_mask[:, j] > 0).sum()) for j, name in enumerate(target_names)
        },
        "high_contact_mae": {
            name: None if not math.isfinite(float(value)) else float(value)
            for name, value in zip(target_names, high_contact_mae_values)
        },
        "high_contact_rmse": {
            name: None if not math.isfinite(float(value)) else float(value)
            for name, value in zip(target_names, high_contact_rmse_values)
        },
    }


def bin_report(x: np.ndarray, y: np.ndarray, targets: list[str]) -> list[dict[str, Any]]:
    if "detector_contact_fraction" in targets:
        idx = targets.index("detector_contact_fraction")
    elif "detector_active_contact_fraction" in targets:
        idx = targets.index("detector_active_contact_fraction")
    else:
        return []
    bins = [(0.0, 0.01), (0.01, 0.10), (0.10, 0.40), (0.40, 0.80), (0.80, 0.98), (0.98, 1.000001)]
    out = []
    for lo, hi in bins:
        mask = (y[:, idx] >= lo) & (y[:, idx] < hi)
        out.append({"bin": f"{lo:.2f}-{hi:.2f}", "count": int(mask.sum())})
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Entrena ensemble MLP para el Digital Twin.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--data", type=Path, default=None)
    parser.add_argument("--model-dir", type=Path, default=None)
    parser.add_argument("--ensemble-size", type=int, default=None)
    parser.add_argument("--epochs", type=int, default=None)
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    train_cfg = dict(dt_cfg["training"])
    if args.ensemble_size is not None:
        train_cfg["ensemble_size"] = args.ensemble_size
    if args.epochs is not None:
        train_cfg["epochs"] = args.epochs
    data_path = (ROOT / str(args.data or dt_cfg["output_dataset"])).resolve()
    input_names = [str(v) for v in dt_cfg["voltage_names"]]
    target_names = [str(v) for v in train_cfg["targets"]]
    x, y, y_mask = load_table(data_path, input_names, target_names)
    model_dir = (ROOT / str(args.model_dir or train_cfg["model_dir"])).resolve()

    reports = []
    for i in range(int(train_cfg["ensemble_size"])):
        seed = 1000 + i
        report = train_one(seed, x, y, y_mask, train_cfg, model_dir, input_names, target_names)
        reports.append(report)
        print(f"modelo {i+1}: val={report['best_val_loss']:.6f} {report['mae']}")

    summary = {
        "data_path": str(data_path),
        "n_rows": int(len(x)),
        "input_names": input_names,
        "target_names": target_names,
        "target_observed_count": {
            name: int((y_mask[:, j] > 0).sum()) for j, name in enumerate(target_names)
        },
        "bin_report": bin_report(x, y, target_names),
        "models": reports,
    }
    model_dir.mkdir(parents=True, exist_ok=True)
    (model_dir / "training_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(json.dumps(summary["bin_report"], indent=2, ensure_ascii=False))
    print(f"Resumen: {model_dir / 'training_summary.json'}")


if __name__ == "__main__":
    main()
