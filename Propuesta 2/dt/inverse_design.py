from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path
from typing import Any

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
    items = []
    for path in sorted(model_dir.glob("model_seed_*.pt")):
        ckpt = torch.load(path, map_location="cpu", weights_only=False)
        model = MLP(
            len(ckpt["input_names"]),
            len(ckpt["target_names"]),
            [int(v) for v in ckpt["hidden_layers"]],
            float(ckpt.get("dropout", 0.0)),
        )
        model.load_state_dict(ckpt["state_dict"])
        model.eval()
        items.append((model, ckpt))
    if not items:
        raise FileNotFoundError(f"No hay modelos en {model_dir}")
    return items


def load_viability_ensemble(model_dir: Path):
    items = []
    for path in sorted(model_dir.glob("viability_seed_*.pt")):
        ckpt = torch.load(path, map_location="cpu", weights_only=False)
        model = ViabilityMLP(
            len(ckpt["input_names"]),
            [int(v) for v in ckpt["hidden_layers"]],
            float(ckpt.get("dropout", 0.0)),
        )
        model.load_state_dict(ckpt["state_dict"])
        model.eval()
        items.append((model, ckpt))
    return items


def read_elites(dt_cfg: dict[str, Any]) -> list[dict[str, float]]:
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    elites = []
    for item in dt_cfg.get("elites", []):
        voltages = {name: float(item["voltages"][name]) for name in voltage_names}
        elites.append(voltages)
    return elites


def tensor_bounds(dt_cfg: dict[str, Any], voltage_names: list[str]) -> tuple[torch.Tensor, torch.Tensor]:
    bounds = dt_cfg["full_bounds"]
    lo = torch.tensor([float(bounds[name][0]) for name in voltage_names], dtype=torch.float32)
    hi = torch.tensor([float(bounds[name][1]) for name in voltage_names], dtype=torch.float32)
    return lo, hi


def scaled_to_voltages(z: torch.Tensor, lo: torch.Tensor, hi: torch.Tensor) -> torch.Tensor:
    # z libre -> [lo, hi], suave y diferenciable.
    return lo + (hi - lo) * torch.sigmoid(z)


def inverse_sigmoid_scaled(v: torch.Tensor, lo: torch.Tensor, hi: torch.Tensor) -> torch.Tensor:
    p = torch.clamp((v - lo) / (hi - lo), 1e-5, 1.0 - 1e-5)
    return torch.log(p / (1.0 - p))


def ensemble_predict(models, voltages: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor, list[str]]:
    preds = []
    target_names: list[str] | None = None
    for model, ckpt in models:
        target_names = [str(v) for v in ckpt["target_names"]]
        x_mean = torch.tensor(ckpt["x_mean"], dtype=torch.float32)
        x_std = torch.tensor(ckpt["x_std"], dtype=torch.float32)
        y_mean = torch.tensor(ckpt["y_mean"], dtype=torch.float32)
        y_std = torch.tensor(ckpt["y_std"], dtype=torch.float32)
        x = (voltages - x_mean) / x_std
        pred_norm = model(x)
        pred = pred_norm * y_std + y_mean
        preds.append(pred)
    stack = torch.stack(preds, dim=0)
    return stack.mean(dim=0), stack.std(dim=0), target_names or []


def viability_predict(models, voltages: torch.Tensor) -> tuple[torch.Tensor | None, torch.Tensor | None]:
    if not models:
        return None, None
    probs = []
    for model, ckpt in models:
        x_mean = torch.tensor(ckpt["x_mean"], dtype=torch.float32)
        x_std = torch.tensor(ckpt["x_std"], dtype=torch.float32)
        x = (voltages - x_mean) / x_std
        probs.append(torch.sigmoid(model(x)))
    stack = torch.stack(probs, dim=0)
    return stack.mean(dim=0), stack.std(dim=0)


def objective_loss(
    pred: torch.Tensor,
    unc: torch.Tensor,
    target_names: list[str],
    args: argparse.Namespace,
    voltages: torch.Tensor,
    lo: torch.Tensor,
    hi: torch.Tensor,
    viability_prob: torch.Tensor | None = None,
) -> torch.Tensor:
    idx = {name: i for i, name in enumerate(target_names)}
    loss = torch.tensor(0.0, dtype=torch.float32)
    if args.target_active is not None and "detector_active_contact_fraction" in idx:
        active = torch.clamp(pred[:, idx["detector_active_contact_fraction"]], 0.0, 1.2)
        loss = loss + args.w_active * (active - float(args.target_active)).pow(2).mean()
    if args.target_forward is not None and "detector_active_forward_fraction" in idx:
        fwd = torch.clamp(pred[:, idx["detector_active_forward_fraction"]], 0.0, 1.2)
        loss = loss + args.w_forward * (fwd - float(args.target_forward)).pow(2).mean()
    if args.target_theta_mean is not None and "detector_contact_angle_theta_mean_deg" in idx:
        theta = torch.clamp(pred[:, idx["detector_contact_angle_theta_mean_deg"]], 0.0, 90.0)
        loss = loss + args.w_theta_mean * (theta - float(args.target_theta_mean)).pow(2).mean()
    if args.target_theta_sigma is not None and "detector_contact_angle_theta_sigma_deg" in idx:
        sig = torch.clamp(pred[:, idx["detector_contact_angle_theta_sigma_deg"]], 0.0, 90.0)
        loss = loss + args.w_theta_sigma_target * (sig - float(args.target_theta_sigma)).pow(2).mean()
    if args.minimize_theta_sigma and "detector_contact_angle_theta_sigma_deg" in idx:
        sig = torch.clamp(pred[:, idx["detector_contact_angle_theta_sigma_deg"]], 0.0, 90.0)
        loss = loss + args.w_theta_sigma * sig.mean()
    if args.minimize_theta_mean and "detector_contact_angle_theta_mean_deg" in idx:
        theta = torch.clamp(pred[:, idx["detector_contact_angle_theta_mean_deg"]], 0.0, 90.0)
        loss = loss + args.w_theta_mean_min * theta.mean()
    if args.w_uncertainty > 0:
        loss = loss + args.w_uncertainty * unc.mean()
    if args.w_voltage_l2 > 0:
        scale = torch.maximum(torch.abs(lo), torch.abs(hi))
        loss = loss + args.w_voltage_l2 * ((voltages / scale).pow(2).mean(dim=1)).mean()
    if args.w_boundary > 0:
        width = hi - lo
        center = (hi + lo) / 2.0
        normalized_radius = torch.abs((voltages - center) / (0.5 * width))
        loss = loss + args.w_boundary * normalized_radius.pow(6).mean()
    if viability_prob is not None and args.w_viability > 0:
        min_prob = float(args.min_viability_prob)
        loss = loss + args.w_viability * torch.relu(min_prob - viability_prob).pow(2).mean()
    return loss


def candidate_rows(
    voltages: torch.Tensor,
    pred: torch.Tensor,
    unc: torch.Tensor,
    target_names: list[str],
    losses: torch.Tensor,
    voltage_names: list[str],
    viability_prob: torch.Tensor | None = None,
    viability_unc: torch.Tensor | None = None,
) -> list[dict[str, float]]:
    rows = []
    v_np = voltages.detach().cpu().numpy()
    p_np = pred.detach().cpu().numpy()
    u_np = unc.detach().cpu().numpy()
    l_np = losses.detach().cpu().numpy()
    vp_np = None if viability_prob is None else viability_prob.detach().cpu().numpy()
    vu_np = None if viability_unc is None else viability_unc.detach().cpu().numpy()
    for i in range(v_np.shape[0]):
        row: dict[str, float] = {"loss": float(l_np[i])}
        for name, value in zip(voltage_names, v_np[i]):
            row[name] = float(value)
        for name, value in zip(target_names, p_np[i]):
            row[f"pred_{name}"] = float(value)
        for name, value in zip(target_names, u_np[i]):
            row[f"unc_{name}"] = float(value)
        if vp_np is not None:
            row["pred_viability_prob"] = float(vp_np[i])
        if vu_np is not None:
            row["unc_viability_prob"] = float(vu_np[i])
        add_predicted_derived_metrics(row)
        rows.append(row)
    rows.sort(key=lambda r: r["loss"])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Diseño inverso diferenciable sobre el DT.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--model-dir", type=Path, default=ROOT / "dt" / "models" / "baseline_mlp")
    parser.add_argument("--target-active", type=float, default=1.0)
    parser.add_argument("--target-forward", type=float, default=1.0)
    parser.add_argument("--target-theta-mean", type=float, default=None)
    parser.add_argument("--target-theta-sigma", type=float, default=None)
    parser.add_argument("--minimize-theta-mean", action="store_true")
    parser.add_argument("--minimize-theta-sigma", action="store_true", default=True)
    parser.add_argument("--no-minimize-theta-sigma", dest="minimize_theta_sigma", action="store_false")
    parser.add_argument("--n-starts", type=int, default=256)
    parser.add_argument("--steps", type=int, default=800)
    parser.add_argument("--lr", type=float, default=0.03)
    parser.add_argument("--top-k", type=int, default=10)
    parser.add_argument("--out", type=Path, default=ROOT / "dt" / "data" / "inverse_candidates.csv")
    parser.add_argument("--w-active", type=float, default=18.0)
    parser.add_argument("--w-forward", type=float, default=4.0)
    parser.add_argument("--w-theta-mean", type=float, default=0.20)
    parser.add_argument("--w-theta-mean-min", type=float, default=0.04)
    parser.add_argument("--w-theta-sigma-target", type=float, default=0.30)
    parser.add_argument("--w-theta-sigma", type=float, default=0.25)
    parser.add_argument("--w-uncertainty", type=float, default=0.15)
    parser.add_argument("--w-voltage-l2", type=float, default=0.01)
    parser.add_argument("--w-boundary", type=float, default=0.01)
    parser.add_argument("--viability-model-dir", type=Path, default=None)
    parser.add_argument("--min-viability-prob", type=float, default=0.70)
    parser.add_argument("--w-viability", type=float, default=6.0)
    parser.add_argument("--seed", type=int, default=20260628)
    args = parser.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    dt_cfg = load_json(args.config.resolve())
    voltage_names = [str(v) for v in dt_cfg["voltage_names"]]
    lo, hi = tensor_bounds(dt_cfg, voltage_names)
    models = load_ensemble(args.model_dir.resolve())
    viability_models = load_viability_ensemble(args.viability_model_dir.resolve()) if args.viability_model_dir else []

    starts = []
    for elite in read_elites(dt_cfg):
        starts.append([elite[name] for name in voltage_names])
    while len(starts) < args.n_starts:
        starts.append((lo + (hi - lo) * torch.rand(len(voltage_names))).tolist())
    starts_t = torch.tensor(starts[: args.n_starts], dtype=torch.float32)
    z = inverse_sigmoid_scaled(starts_t, lo, hi).detach().clone().requires_grad_(True)
    opt = torch.optim.Adam([z], lr=args.lr)

    best_loss = None
    best_v = None
    for step in range(1, args.steps + 1):
        voltages = scaled_to_voltages(z, lo, hi)
        pred, unc, target_names = ensemble_predict(models, voltages)
        viability_prob, _viability_unc = viability_predict(viability_models, voltages)
        # pérdida por candidato para seleccionar, y media para optimizar batch.
        losses = []
        for i in range(voltages.shape[0]):
            losses.append(
                objective_loss(
                    pred[i : i + 1],
                    unc[i : i + 1],
                    target_names,
                    args,
                    voltages[i : i + 1],
                    lo,
                    hi,
                    None if viability_prob is None else viability_prob[i : i + 1],
                )
            )
        loss_vec = torch.stack(losses)
        loss = loss_vec.mean()
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        with torch.no_grad():
            current_best = float(loss_vec.min().detach().cpu())
            if best_loss is None or current_best < best_loss:
                best_loss = current_best
                best_v = voltages[torch.argmin(loss_vec)].detach().clone()
        if step % max(1, args.steps // 5) == 0 or step == 1:
            print(f"step {step}/{args.steps} batch_loss={float(loss.detach()):.6f} best={current_best:.6f}")

    with torch.no_grad():
        voltages = scaled_to_voltages(z, lo, hi)
        pred, unc, target_names = ensemble_predict(models, voltages)
        viability_prob, viability_unc = viability_predict(viability_models, voltages)
        losses = torch.stack([
            objective_loss(
                pred[i : i + 1],
                unc[i : i + 1],
                target_names,
                args,
                voltages[i : i + 1],
                lo,
                hi,
                None if viability_prob is None else viability_prob[i : i + 1],
            )
            for i in range(voltages.shape[0])
        ])
    rows = candidate_rows(voltages, pred, unc, target_names, losses, voltage_names, viability_prob, viability_unc)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows[: args.top_k])

    print(f"Candidatos: {args.out}")
    for row in rows[: args.top_k]:
        print(
            f"loss={row['loss']:.5f} "
            f"active={100*row.get('pred_detector_active_contact_fraction', 0.0):.2f}% "
            f"fwd={100*row.get('pred_detector_active_forward_fraction', 0.0):.2f}% "
            f"theta_mu={row.get('pred_detector_contact_angle_theta_mean_deg', 0.0):.3f} "
            f"theta_sig={row.get('pred_detector_contact_angle_theta_sigma_deg', 0.0):.3f} | "
            + (f"viab={row['pred_viability_prob']:.3f} | " if "pred_viability_prob" in row else "")
            + " ".join(f"{name}={row[name]:.6g}" for name in voltage_names)
        )


if __name__ == "__main__":
    main()
