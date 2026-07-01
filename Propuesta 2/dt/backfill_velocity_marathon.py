from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def run_stream(cmd: list[str], log_path: Path) -> None:
    print("\n> " + " ".join(cmd), flush=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8", errors="replace") as log:
        log.write("\n" + "=" * 100 + "\n")
        log.write(datetime.now().isoformat(timespec="seconds") + "\n")
        log.write("> " + " ".join(cmd) + "\n")
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
        for line in process.stdout:
            print(line, end="")
            log.write(line)
        code = process.wait()
        if code != 0:
            raise RuntimeError(f"Falló comando con código {code}: {' '.join(cmd)}")


def load_json(path: Path, default: Any) -> Any:
    if not path.is_file():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return default


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")


def dataset_counts() -> dict[str, int]:
    import csv

    from dt.derived_metrics import residual_from_row

    dataset = ROOT / "dt" / "data" / "dt_detector_window_dataset.csv"
    if not dataset.is_file():
        return {"rows": 0, "residual_rows": 0}
    with dataset.open("r", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return {
        "rows": len(rows),
        "residual_rows": sum(1 for row in rows if residual_from_row(row) is not None),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Maratón desatendida: backfill de residual vz_sigma por lotes + reentrenamiento."
    )
    parser.add_argument("--n", type=int, default=1800, help="Puntos de backfill a intentar.")
    parser.add_argument("--batch-size", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260701)
    parser.add_argument("--train-every", type=int, default=300, help="Reentrena cada N puntos agregados. 0 = solo final.")
    parser.add_argument("--epochs", type=int, default=800)
    parser.add_argument("--ensemble-size", type=int, default=5)
    parser.add_argument("--viability-epochs", type=int, default=500)
    parser.add_argument("--viability-ensemble-size", type=int, default=5)
    parser.add_argument("--skip-viability", action="store_true")
    parser.add_argument("--no-final-train", action="store_true")
    parser.add_argument("--state", type=Path, default=ROOT / "dt" / "models" / "velocity_backfill_marathon_state.json")
    parser.add_argument("--log", type=Path, default=ROOT / "dt" / "models" / "velocity_backfill_marathon.log")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    py = sys.executable
    state_path = args.state.resolve()
    log_path = args.log.resolve()
    state = load_json(state_path, {})
    done = int(state.get("done", 0))
    batches = int(state.get("batches", 0))
    last_train_at = int(state.get("last_train_at", 0))
    start_counts = dataset_counts()

    print(f"Estado inicial: done={done}, batches={batches}, counts={start_counts}")
    if args.dry_run:
        print("DRY RUN: no se ejecutan backfills ni entrenamientos.")

    def train_all(reason: str) -> None:
        nonlocal last_train_at
        print(f"\n=== Reentrenamiento ({reason}) en done={done} ===", flush=True)
        if args.dry_run:
            return
        run_stream(
            [
                py,
                str(ROOT / "dt" / "train_dt.py"),
                "--ensemble-size",
                str(args.ensemble_size),
                "--epochs",
                str(args.epochs),
            ],
            log_path,
        )
        if not args.skip_viability:
            run_stream(
                [
                    py,
                    str(ROOT / "dt" / "train_viability.py"),
                    "--ensemble-size",
                    str(args.viability_ensemble_size),
                    "--epochs",
                    str(args.viability_epochs),
                ],
                log_path,
            )
        last_train_at = done

    while done < args.n:
        remaining = args.n - done
        batch_n = min(args.batch_size, remaining)
        batch_seed = args.seed + batches
        print(f"\n=== Batch {batches + 1}: n={batch_n}, seed={batch_seed}, done={done}/{args.n} ===")
        if not args.dry_run:
            before = dataset_counts()
            run_stream(
                [
                    py,
                    str(ROOT / "dt" / "backfill_velocity_residual.py"),
                    "--n",
                    str(batch_n),
                    "--seed",
                    str(batch_seed),
                ],
                log_path,
            )
            after = dataset_counts()
            added = max(0, after["residual_rows"] - before["residual_rows"])
        else:
            added = batch_n
            after = dataset_counts()

        done += added
        batches += 1
        state = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "requested_n": args.n,
            "done": done,
            "batches": batches,
            "last_train_at": last_train_at,
            "counts": after,
            "last_batch_requested": batch_n,
            "last_batch_added_residual_rows": added,
        }
        if not args.dry_run:
            save_state(state_path, state)

        if added == 0:
            print("No se agregaron nuevos residuales; probablemente no quedan puntos elegibles. Detengo.")
            break

        if args.train_every > 0 and done - last_train_at >= args.train_every:
            train_all(f"periodico cada {args.train_every}")
            state["last_train_at"] = last_train_at
            state["counts"] = dataset_counts()
            if not args.dry_run:
                save_state(state_path, state)

    if not args.no_final_train and done > last_train_at:
        train_all("final")
        state = load_json(state_path, state)
        state["last_train_at"] = last_train_at
        state["counts"] = dataset_counts()
        state["timestamp"] = datetime.now().isoformat(timespec="seconds")
        save_state(state_path, state)

    print(f"\nMaratón terminada. Estado: {state_path}")
    print(f"Log: {log_path}")
    print(json.dumps(load_json(state_path, {}), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
