from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def run_step(cmd: list[str], log_path: Path | None = None) -> None:
    print("\n> " + " ".join(cmd), flush=True)
    process = subprocess.Popen(
        cmd,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert process.stdout is not None
    log_file = None
    try:
        if log_path is not None:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_file = log_path.open("a", encoding="utf-8")
            log_file.write("\n" + "=" * 80 + "\n")
            log_file.write(datetime.now().isoformat(timespec="seconds") + "\n")
            log_file.write("> " + " ".join(cmd) + "\n")
        for line in process.stdout:
            print(line, end="")
            if log_file is not None:
                log_file.write(line)
    finally:
        if log_file is not None:
            log_file.close()
    code = process.wait()
    if code != 0:
        raise RuntimeError(f"Falló comando con código {code}: {' '.join(cmd)}")


def dataset_count(path: Path) -> int:
    if not path.is_file():
        return 0
    # Resta encabezado.
    with path.open("r", encoding="utf-8", errors="replace") as f:
        return max(0, sum(1 for _ in f) - 1)


def high_contact_mean(summary: dict[str, Any], metric: str) -> float | None:
    vals = []
    for model in summary.get("models", []):
        value = model.get("high_contact_mae", {}).get(metric)
        if value is not None:
            vals.append(float(value))
    if not vals:
        return None
    return sum(vals) / len(vals)


def metric_name(summary: dict[str, Any], preferred: list[str]) -> str | None:
    targets = [str(v) for v in summary.get("target_names", [])]
    for name in preferred:
        if name in targets:
            return name
    return None


def summarize_training(summary_path: Path) -> dict[str, Any]:
    summary = load_json(summary_path)
    contact_metric = metric_name(summary, ["detector_active_contact_fraction", "detector_contact_fraction"])
    theta_mean_metric = metric_name(summary, ["detector_contact_angle_theta_mean_deg", "terminal_angle_theta_mean_deg"])
    theta_spread_metric = metric_name(summary, ["detector_contact_angle_theta_sigma_deg", "terminal_angle_theta_p95_deg"])
    out = {
        "n_rows": int(summary.get("n_rows", 0)),
        "high_contact_contact_mae": high_contact_mean(summary, contact_metric) if contact_metric else None,
        "high_contact_theta_mean_mae": high_contact_mean(summary, theta_mean_metric) if theta_mean_metric else None,
        "high_contact_theta_spread_mae": high_contact_mean(summary, theta_spread_metric) if theta_spread_metric else None,
        "global_contact_mae": None,
        "global_theta_spread_mae": None,
    }
    global_contact = []
    global_theta95 = []
    for model in summary.get("models", []):
        if "mae" in model:
            if contact_metric and contact_metric in model["mae"]:
                global_contact.append(float(model["mae"][contact_metric]))
            if theta_spread_metric and theta_spread_metric in model["mae"]:
                global_theta95.append(float(model["mae"][theta_spread_metric]))
    if global_contact:
        out["global_contact_mae"] = sum(global_contact) / len(global_contact)
    if global_theta95:
        out["global_theta_spread_mae"] = sum(global_theta95) / len(global_theta95)
    return out


def append_loop_summary(path: Path, row: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    if path.is_file():
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            rows = []
    rows.append(row)
    path.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Bucle automático de aprendizaje activo para el DT.")
    parser.add_argument("--cycles", type=int, default=4)
    parser.add_argument("--points-per-cycle", type=int, default=50)
    parser.add_argument("--pool", type=int, default=6000)
    parser.add_argument("--ensemble-size", type=int, default=5)
    parser.add_argument("--viability-ensemble-size", type=int, default=5)
    parser.add_argument("--epochs", type=int, default=800)
    parser.add_argument("--viability-epochs", type=int, default=500)
    parser.add_argument("--viability-threshold", type=float, default=0.05)
    parser.add_argument("--min-theta95-improvement", type=float, default=0.10)
    parser.add_argument("--patience-cycles", type=int, default=2)
    parser.add_argument("--skip-initial-train", action="store_true")
    parser.add_argument("--no-final-train", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    py = sys.executable
    dt_cfg = load_json(ROOT / "dt" / "dt_config.json")
    dataset_path = ROOT / str(dt_cfg["output_dataset"])
    model_dir = ROOT / str(dt_cfg["training"]["model_dir"])
    summary_path = model_dir / "training_summary.json"
    loop_summary_path = ROOT / "dt" / "models" / "active_loop_summary.json"
    log_path = ROOT / "dt" / "models" / "active_loop.log"

    def train_cmd() -> list[str]:
        return [
            py,
            str(ROOT / "dt" / "train_dt.py"),
            "--ensemble-size",
            str(args.ensemble_size),
            "--epochs",
            str(args.epochs),
        ]

    def train_viability_cmd() -> list[str]:
        return [
            py,
            str(ROOT / "dt" / "train_viability.py"),
            "--threshold",
            str(args.viability_threshold),
            "--ensemble-size",
            str(args.viability_ensemble_size),
            "--epochs",
            str(args.viability_epochs),
        ]

    def active_cmd(cycle: int) -> list[str]:
        return [
            py,
            str(ROOT / "dt" / "active_select.py"),
            "--pool",
            str(args.pool),
            "--select",
            str(args.points_per_cycle),
            "--out",
            str(ROOT / "dt" / "data" / f"active_candidates_cycle_{cycle:02d}.csv"),
            "--viability-model-dir",
            str(ROOT / "dt" / "models" / "viability_mlp"),
            "--max-failures",
            str(max(5, args.points_per_cycle // 5)),
            "--timeout-seconds",
            "180",
            "--run-simion",
        ]

    best_theta95: float | None = None
    stale = 0

    if not args.skip_initial_train:
        if not args.dry_run:
            run_step(train_cmd(), log_path)
            run_step(train_viability_cmd(), log_path)
        else:
            print("DRY train:", " ".join(train_cmd()))
            print("DRY viability:", " ".join(train_viability_cmd()))

    for cycle in range(1, args.cycles + 1):
        before_count = dataset_count(dataset_path)
        before_metrics = summarize_training(summary_path) if summary_path.is_file() else {}
        if before_metrics:
            theta95 = before_metrics.get("high_contact_theta_spread_mae")
            if theta95 is not None:
                if best_theta95 is None or theta95 < best_theta95 - args.min_theta95_improvement:
                    best_theta95 = float(theta95)
                    stale = 0
                else:
                    stale += 1

        row: dict[str, Any] = {
            "cycle": cycle,
            "timestamp_start": datetime.now().isoformat(timespec="seconds"),
            "rows_before": before_count,
            "metrics_before": before_metrics,
        }

        if stale >= args.patience_cycles:
            row["stopped"] = f"sin mejora angular high-contact por {stale} ciclos"
            append_loop_summary(loop_summary_path, row)
            print(row["stopped"])
            break

        if not args.dry_run:
            run_step(active_cmd(cycle), log_path)
        else:
            print("DRY active:", " ".join(active_cmd(cycle)))

        after_active_count = dataset_count(dataset_path)
        row["rows_after_active"] = after_active_count
        row["new_rows"] = after_active_count - before_count

        if not args.dry_run:
            run_step(train_cmd(), log_path)
            run_step(train_viability_cmd(), log_path)
            row["metrics_after_train"] = summarize_training(summary_path)
        else:
            print("DRY train:", " ".join(train_cmd()))
            print("DRY viability:", " ".join(train_viability_cmd()))

        row["timestamp_end"] = datetime.now().isoformat(timespec="seconds")
        append_loop_summary(loop_summary_path, row)

    if not args.no_final_train and args.skip_initial_train:
        # Seguridad: si se arrancó sin entrenamiento inicial y se abortó antes del primer ciclo,
        # permite generar un resumen actualizado al final.
        if not args.dry_run:
            run_step(train_cmd(), log_path)

    print(f"Resumen del bucle: {loop_summary_path}")
    print(f"Log: {log_path}")


if __name__ == "__main__":
    main()
