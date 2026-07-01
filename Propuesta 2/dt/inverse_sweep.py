from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


DEFAULT_CASES = [
    # name, active, theta_mean_deg, theta_sigma_deg
    ("active35_soft", 0.35, 6.0, 3.0),
    ("active50_mid", 0.50, 5.0, 2.5),
    ("active65_mid", 0.65, 4.5, 2.0),
    ("active80_good", 0.80, 3.5, 1.6),
    ("active92_good", 0.92, 2.8, 1.2),
    ("active99_tight", 0.99, 2.1, 0.9),
]


def run(cmd: list[str]) -> None:
    print("> " + " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Barrido de dise\u00f1o inverso DT: objetivos variados -> validaci\u00f3n SIMION."
    )
    parser.add_argument("--steps", type=int, default=500)
    parser.add_argument("--n-starts", type=int, default=192)
    parser.add_argument("--top-k", type=int, default=6)
    parser.add_argument("--validate-top", type=int, default=2)
    parser.add_argument("--out-dir", type=Path, default=ROOT / "dt" / "data" / "inverse_sweep")
    parser.add_argument("--skip-validation", action="store_true")
    parser.add_argument("--viability-model-dir", type=Path, default=None)
    parser.add_argument("--min-viability-prob", type=float, default=0.70)
    parser.add_argument("--w-viability", type=float, default=6.0)
    parser.add_argument(
        "--case",
        action="append",
        default=[],
        help="Caso manual: nombre,active,theta_mean,theta_sigma. Puede repetirse.",
    )
    args = parser.parse_args()

    cases = []
    if args.case:
        for raw in args.case:
            name, active, theta_mean, theta_sigma = [v.strip() for v in raw.split(",")]
            cases.append((name, float(active), float(theta_mean), float(theta_sigma)))
    else:
        cases = DEFAULT_CASES

    args.out_dir.mkdir(parents=True, exist_ok=True)
    py = sys.executable
    summary_rows: list[dict[str, str | float | int]] = []

    for idx, (name, active, theta_mean, theta_sigma) in enumerate(cases, start=1):
        print(
            f"\n=== {idx}/{len(cases)} {name}: "
            f"active={active:.3f}, theta_mean={theta_mean:.3f}, theta_sigma={theta_sigma:.3f} ===",
            flush=True,
        )
        cand_path = args.out_dir / f"{idx:02d}_{name}_candidates.csv"
        val_path = args.out_dir / f"{idx:02d}_{name}_validation.csv"

        inverse_cmd = [
            py,
            str(ROOT / "dt" / "inverse_design.py"),
            "--target-active",
            str(active),
            "--target-forward",
            "1.0",
            "--target-theta-mean",
            str(theta_mean),
            "--target-theta-sigma",
            str(theta_sigma),
            "--no-minimize-theta-sigma",
            "--n-starts",
            str(args.n_starts),
            "--steps",
            str(args.steps),
            "--top-k",
            str(args.top_k),
            "--out",
            str(cand_path),
        ]
        if args.viability_model_dir is not None:
            inverse_cmd.extend(
                [
                    "--viability-model-dir",
                    str(args.viability_model_dir),
                    "--min-viability-prob",
                    str(args.min_viability_prob),
                    "--w-viability",
                    str(args.w_viability),
                ]
            )
        run(inverse_cmd)

        if not args.skip_validation:
            validate_cmd = [
                py,
                str(ROOT / "dt" / "validate_candidates.py"),
                "--candidates",
                str(cand_path),
                "--top",
                str(args.validate_top),
                "--out",
                str(val_path),
            ]
            run(validate_cmd)
            for row in read_rows(val_path):
                row_out: dict[str, str | float | int] = {
                    "case": name,
                    "target_active": active,
                    "target_theta_mean": theta_mean,
                    "target_theta_sigma": theta_sigma,
                    **row,
                }
                summary_rows.append(row_out)

    if summary_rows:
        summary_path = args.out_dir / "summary.csv"
        fieldnames: list[str] = []
        for row in summary_rows:
            for key in row.keys():
                if key not in fieldnames:
                    fieldnames.append(key)
        with summary_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(summary_rows)
        print(f"\nResumen: {summary_path}", flush=True)


if __name__ == "__main__":
    main()
