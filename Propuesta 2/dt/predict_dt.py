from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch
from torch import nn

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dt.derived_metrics import add_predicted_derived_metrics


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


def load_model(path: Path) -> tuple[MLP, dict]:
    ckpt = torch.load(path, map_location="cpu", weights_only=False)
    model = MLP(
        len(ckpt["input_names"]),
        len(ckpt["target_names"]),
        [int(v) for v in ckpt["hidden_layers"]],
        float(ckpt.get("dropout", 0.0)),
    )
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    return model, ckpt


def inverse_transform(y: np.ndarray, target_names: list[str], transform: str) -> np.ndarray:
    expected = [
        "detector_contact_fraction",
        "terminal_angle_theta_mean_deg",
        "terminal_angle_theta_p95_deg",
        "terminal_angle_theta_p99_deg",
    ]
    if transform != "contact_angle_monotonic" or target_names != expected:
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Predice métricas con el ensemble DT.")
    parser.add_argument("--model-dir", type=Path, default=ROOT / "dt" / "models" / "baseline_mlp")
    parser.add_argument("--voltages", nargs="+", required=True, help="Ej: V3=-900 V6=-1000 ...")
    args = parser.parse_args()

    values = {}
    for item in args.voltages:
        key, raw = item.split("=", 1)
        values[key.upper()] = float(raw)

    preds = []
    target_names = None
    for model_path in sorted(args.model_dir.glob("model_seed_*.pt")):
        model, ckpt = load_model(model_path)
        input_names = [str(v) for v in ckpt["input_names"]]
        target_names = [str(v) for v in ckpt["target_names"]]
        x = np.asarray([[values[name] for name in input_names]], dtype=np.float32)
        x_norm = (x - ckpt["x_mean"]) / ckpt["x_std"]
        with torch.no_grad():
            y_norm = model(torch.from_numpy(x_norm)).numpy()
        y_fit = y_norm * ckpt["y_std"] + ckpt["y_mean"]
        y = inverse_transform(
            y_fit,
            [str(v) for v in ckpt["target_names"]],
            str(ckpt.get("target_transform", "identity")),
        )
        preds.append(y[0])
    if not preds:
        raise FileNotFoundError(f"No encontré modelos en {args.model_dir}")
    arr = np.vstack(preds)
    mean = arr.mean(axis=0)
    std = arr.std(axis=0)
    result = {
        name: {"mean": float(m), "ensemble_std": float(s)}
        for name, m, s in zip(target_names or [], mean, std)
    }
    flat = {f"pred_{name}": float(value) for name, value in zip(target_names or [], mean)}
    add_predicted_derived_metrics(flat)
    for key in ["derived_vz_mean", "derived_vz_sigma_physics", "derived_vz_sigma_corrected"]:
        if key in flat:
            result[key] = {"mean": float(flat[key]), "ensemble_std": 0.0}
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
