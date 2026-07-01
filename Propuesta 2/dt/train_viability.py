from __future__ import annotations

import argparse
import csv
import json
import math
import random
from pathlib import Path
from typing import Any

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, TensorDataset

ROOT = Path(__file__).resolve().parents[1]


class MLP(nn.Module):
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


def standardize(arr: np.ndarray, eps: float = 1e-8) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = arr.mean(axis=0)
    std = arr.std(axis=0)
    std = np.where(std < eps, 1.0, std)
    return (arr - mean) / std, mean.astype(np.float32), std.astype(np.float32)


def load_table(path: Path, voltage_names: list[str], contact_key: str, threshold: float) -> tuple[np.ndarray, np.ndarray]:
    xs: list[list[float]] = []
    ys: list[float] = []
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                x = [float(row[name]) for name in voltage_names]
                contact = float(row[contact_key])
            except (KeyError, TypeError, ValueError):
                continue
            if all(math.isfinite(v) for v in x) and math.isfinite(contact):
                xs.append(x)
                ys.append(1.0 if contact >= threshold else 0.0)
    if not xs:
        raise ValueError(f"No hay filas para entrenar viabilidad en {path}")
    return np.asarray(xs, dtype=np.float32), np.asarray(ys, dtype=np.float32)


def train_one(
    seed: int,
    x: np.ndarray,
    y: np.ndarray,
    cfg: dict[str, Any],
    model_dir: Path,
    voltage_names: list[str],
    threshold: float,
) -> dict[str, Any]:
    torch.manual_seed(seed)
    np.random.seed(seed)
    random.seed(seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    idx = np.arange(len(x))
    rng = np.random.default_rng(seed)
    rng.shuffle(idx)
    n_val = max(1, int(round(len(x) * float(cfg.get("validation_fraction", 0.2)))))
    val_idx = idx[:n_val]
    train_idx = idx[n_val:]
    if len(train_idx) == 0:
        train_idx = val_idx

    _, x_mean, x_std = standardize(x[train_idx])
    x_train = ((x[train_idx] - x_mean) / x_std).astype(np.float32)
    x_val = ((x[val_idx] - x_mean) / x_std).astype(np.float32)
    y_train = y[train_idx].astype(np.float32)
    y_val = y[val_idx].astype(np.float32)

    pos = float(y_train.sum())
    neg = float(len(y_train) - pos)
    pos_weight = torch.tensor([neg / max(pos, 1.0)], dtype=torch.float32, device=device)

    model = MLP(
        n_in=x.shape[1],
        hidden=[int(v) for v in cfg.get("hidden_layers", [128, 128, 64])],
        dropout=float(cfg.get("dropout", 0.03)),
    ).to(device)
    opt = torch.optim.AdamW(
        model.parameters(),
        lr=float(cfg.get("learning_rate", 1e-3)),
        weight_decay=float(cfg.get("weight_decay", 1e-4)),
    )
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
    train_loader = DataLoader(
        TensorDataset(torch.from_numpy(x_train), torch.from_numpy(y_train)),
        batch_size=min(int(cfg.get("batch_size", 64)), max(1, len(train_idx))),
        shuffle=True,
    )
    x_val_t = torch.from_numpy(x_val).to(device)
    y_val_t = torch.from_numpy(y_val).to(device)

    best_state = None
    best_val = float("inf")
    bad = 0
    patience = int(cfg.get("patience", 80))
    for _epoch in range(1, int(cfg.get("epochs", 800)) + 1):
        model.train()
        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)
            logits = model(xb)
            loss = loss_fn(logits, yb)
            opt.zero_grad(set_to_none=True)
            loss.backward()
            opt.step()
        model.eval()
        with torch.no_grad():
            val_loss = float(loss_fn(model(x_val_t), y_val_t).detach().cpu())
        if val_loss < best_val - 1e-6:
            best_val = val_loss
            bad = 0
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
        else:
            bad += 1
        if bad >= patience:
            break

    if best_state is not None:
        model.load_state_dict(best_state)
    model.eval()
    with torch.no_grad():
        prob = torch.sigmoid(model(x_val_t)).detach().cpu().numpy()
    pred = (prob >= 0.5).astype(np.float32)
    acc = float((pred == y_val).mean())
    tp = int(((pred == 1) & (y_val == 1)).sum())
    tn = int(((pred == 0) & (y_val == 0)).sum())
    fp = int(((pred == 1) & (y_val == 0)).sum())
    fn = int(((pred == 0) & (y_val == 1)).sum())

    model_dir.mkdir(parents=True, exist_ok=True)
    model_path = model_dir / f"viability_seed_{seed}.pt"
    torch.save(
        {
            "state_dict": model.state_dict(),
            "input_names": voltage_names,
            "x_mean": x_mean,
            "x_std": x_std,
            "threshold": threshold,
            "hidden_layers": [int(v) for v in cfg.get("hidden_layers", [128, 128, 64])],
            "dropout": float(cfg.get("dropout", 0.03)),
        },
        model_path,
    )
    return {
        "seed": seed,
        "best_val_loss": best_val,
        "accuracy": acc,
        "tp": tp,
        "tn": tn,
        "fp": fp,
        "fn": fn,
        "model_path": str(model_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Entrena clasificador de viabilidad para el DT.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--data", type=Path, default=None)
    parser.add_argument("--threshold", type=float, default=0.05)
    parser.add_argument("--ensemble-size", type=int, default=5)
    parser.add_argument("--epochs", type=int, default=800)
    parser.add_argument("--model-dir", type=Path, default=ROOT / "dt" / "models" / "viability_mlp")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    train_cfg = dict(dt_cfg["training"])
    train_cfg["epochs"] = args.epochs
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    data_path = (ROOT / str(args.data or dt_cfg["output_dataset"])).resolve()
    x, y = load_table(data_path, voltage_names, "detector_active_contact_fraction", args.threshold)
    reports = []
    for i in range(args.ensemble_size):
        report = train_one(2000 + i, x, y, train_cfg, args.model_dir.resolve(), voltage_names, args.threshold)
        reports.append(report)
        print(
            f"clasificador {i+1}: val={report['best_val_loss']:.6f} "
            f"acc={report['accuracy']:.3f} fp={report['fp']} fn={report['fn']}"
        )
    summary = {
        "data_path": str(data_path),
        "n_rows": int(len(x)),
        "positive_rate": float(y.mean()),
        "threshold": args.threshold,
        "models": reports,
    }
    args.model_dir.mkdir(parents=True, exist_ok=True)
    (args.model_dir / "viability_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"Resumen: {args.model_dir / 'viability_summary.json'}")


if __name__ == "__main__":
    main()
