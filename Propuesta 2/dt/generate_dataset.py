from __future__ import annotations

import argparse
import csv
import json
import math
import random
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from optimize import load_config, run_hackathon_fastadj  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def weighted_choice(weights: dict[str, float], rng: random.Random) -> str:
    total = sum(max(0.0, float(v)) for v in weights.values())
    if total <= 0:
        raise ValueError("Los pesos de muestreo deben sumar > 0")
    pick = rng.random() * total
    acc = 0.0
    for key, value in weights.items():
        acc += max(0.0, float(value))
        if pick <= acc:
            return key
    return next(reversed(weights))


def full_voltage_vector(dt_cfg: dict[str, Any], free_voltages: dict[str, float]) -> dict[str, float]:
    out = {str(k): float(v) for k, v in dt_cfg.get("fixed_voltages", {}).items()}
    out.update({str(k): float(v) for k, v in free_voltages.items()})
    return dict(sorted(out.items(), key=lambda item: int(item[0][1:])))


def key_for(voltage_names: list[str], values: dict[str, float], round_v: float) -> tuple[float, ...]:
    if round_v <= 0:
        return tuple(float(values[name]) for name in voltage_names)
    return tuple(round(float(values[name]) / round_v) * round_v for name in voltage_names)


def existing_keys(path: Path, voltage_names: list[str], round_v: float) -> set[tuple[float, ...]]:
    if not path.is_file():
        return set()
    keys: set[tuple[float, ...]] = set()
    with path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                values = {name: float(row[name]) for name in voltage_names}
            except (KeyError, TypeError, ValueError):
                continue
            keys.add(key_for(voltage_names, values, round_v))
    return keys


def lhs_points(
    n: int,
    voltage_names: list[str],
    bounds: dict[str, list[float]],
    rng: random.Random,
) -> list[dict[str, float]]:
    # Latin Hypercube simple, sin dependencia obligatoria de scipy.
    dim = len(voltage_names)
    columns: list[list[float]] = []
    for _ in range(dim):
        vals = [(i + rng.random()) / max(n, 1) for i in range(n)]
        rng.shuffle(vals)
        columns.append(vals)
    points: list[dict[str, float]] = []
    for i in range(n):
        point: dict[str, float] = {}
        for j, name in enumerate(voltage_names):
            lo, hi = [float(x) for x in bounds[name]]
            point[name] = lo + columns[j][i] * (hi - lo)
        points.append(point)
    return points


def _lhs_unit(n: int, dim: int, rng: random.Random) -> list[list[float]]:
    columns: list[list[float]] = []
    for _ in range(dim):
        vals = [(i + rng.random()) / max(n, 1) for i in range(n)]
        rng.shuffle(vals)
        columns.append(vals)
    return [[columns[j][i] for j in range(dim)] for i in range(n)]


def _min_sq_distance(points: list[list[float]]) -> float:
    if len(points) < 2:
        return float("inf")
    best = float("inf")
    for i in range(len(points)):
        pi = points[i]
        for j in range(i + 1, len(points)):
            d = sum((a - b) ** 2 for a, b in zip(pi, points[j]))
            if d < best:
                best = d
    return best


def olhs_points(
    n: int,
    voltage_names: list[str],
    bounds: dict[str, list[float]],
    rng: random.Random,
    restarts: int = 64,
) -> list[dict[str, float]]:
    """Aproximación OLHS/maximin sin dependencia de scipy.

    Genera varios Latin Hypercubes y conserva el diseño con mayor distancia
    mínima normalizada. No es un OLHS matemáticamente exacto, pero es la mejora
    práctica que queremos para presupuestos pequeños.
    """
    dim = len(voltage_names)
    best_unit: list[list[float]] | None = None
    best_score = -1.0
    for _ in range(max(1, int(restarts))):
        unit = _lhs_unit(n, dim, rng)
        score = _min_sq_distance(unit)
        if score > best_score:
            best_score = score
            best_unit = unit
    points: list[dict[str, float]] = []
    for unit_point in best_unit or []:
        point: dict[str, float] = {}
        for name, u in zip(voltage_names, unit_point):
            lo, hi = [float(x) for x in bounds[name]]
            point[name] = lo + u * (hi - lo)
        points.append(point)
    return points


class CandidateSampler:
    def __init__(self, dt_cfg: dict[str, Any], seed: int):
        self.cfg = dt_cfg
        self.rng = random.Random(seed)
        self.voltage_names = [str(x) for x in dt_cfg["voltage_names"]]
        self.bounds = {
            str(k): [float(v[0]), float(v[1])]
            for k, v in dt_cfg["full_bounds"].items()
        }
        self.elites = [
            {str(k): float(v) for k, v in item["voltages"].items()}
            for item in dt_cfg["elites"]
        ]
        self.sampling = dict(dt_cfg["sampling"])
        self._global_pool: list[dict[str, float]] = []

    def clip(self, values: dict[str, float]) -> dict[str, float]:
        return {
            name: clamp(float(values[name]), self.bounds[name][0], self.bounds[name][1])
            for name in self.voltage_names
        }

    def elite(self) -> dict[str, float]:
        return dict(self.rng.choice(self.elites))

    def local_gaussian(self) -> dict[str, float]:
        base = self.elite()
        sigma = float(self.rng.choice(self.sampling["local_sigmas_v"]))
        values = {
            name: float(base[name]) + self.rng.gauss(0.0, sigma)
            for name in self.voltage_names
        }
        return self.clip(values)

    def axis_scan(self) -> dict[str, float]:
        base = self.elite()
        name = self.rng.choice(self.voltage_names)
        step = float(self.rng.choice(self.sampling["axis_steps_v"]))
        base[name] = float(base[name]) + step
        return self.clip(base)

    def between_elites(self) -> dict[str, float]:
        a = self.elite()
        b = self.elite()
        # Permitimos extrapolación suave para salir de la línea entre elites.
        t = self.rng.uniform(-0.25, 1.25)
        jitter = float(self.rng.choice([0.0, 10.0, 25.0, 60.0]))
        values = {}
        for name in self.voltage_names:
            values[name] = (1.0 - t) * float(a[name]) + t * float(b[name])
            if jitter:
                values[name] += self.rng.gauss(0.0, jitter)
        return self.clip(values)

    def global_lhs(self) -> dict[str, float]:
        if not self._global_pool:
            restarts = int(self.sampling.get("olhs_restarts", 64))
            self._global_pool = olhs_points(512, self.voltage_names, self.bounds, self.rng, restarts)
        return self._global_pool.pop()

    def sample(self) -> tuple[str, dict[str, float]]:
        mode = weighted_choice(dict(self.sampling["weights"]), self.rng)
        if mode == "elite_exact":
            return mode, self.clip(self.elite())
        if mode == "local_gaussian":
            return mode, self.local_gaussian()
        if mode == "axis_scan":
            return mode, self.axis_scan()
        if mode == "between_elites":
            return mode, self.between_elites()
        if mode == "global_lhs":
            return mode, self.clip(self.global_lhs())
        raise ValueError(f"Modo de muestreo desconocido: {mode}")


def flatten_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    keep: dict[str, Any] = {}
    for key, value in metrics.items():
        if isinstance(value, (int, float, str)) or value is None:
            keep[key] = value
    return keep


def append_row(path: Path, row: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing_header: list[str] = []
    existing_rows: list[dict[str, Any]] = []
    if path.is_file():
        with path.open("r", newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            existing_header = list(reader.fieldnames or [])
            existing_rows = list(reader)
    header = list(existing_header)
    for key in row.keys():
        if key not in header:
            header.append(key)
    if not header:
        header = list(row.keys())
    # Si aparecen columnas nuevas, reescribe el CSV completo con el encabezado expandido.
    mode = "w" if existing_rows or existing_header else "a"
    with path.open(mode, newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        for old in existing_rows:
            writer.writerow({name: old.get(name, "") for name in header})
        writer.writerow({name: row.get(name, "") for name in header})


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera dataset SIMION para el Digital Twin.")
    parser.add_argument("--config", type=Path, default=ROOT / "dt" / "dt_config.json")
    parser.add_argument("--n", type=int, default=20, help="Número de nuevos puntos a generar.")
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true", help="Solo imprime candidatos; no corre SIMION.")
    parser.add_argument("--include-duplicates", action="store_true")
    args = parser.parse_args()

    dt_cfg = load_json(args.config.resolve())
    out_path = (ROOT / str(args.out or dt_cfg["output_dataset"])).resolve()
    simion_cfg = load_config(ROOT / str(dt_cfg["base_simion_config"]))
    simion_cfg["voltage_bounds"] = dt_cfg["full_bounds"]
    simion_cfg["fixed_voltages"] = dt_cfg["fixed_voltages"]
    simion_cfg["optimized_electrodes"] = [
        int(name[1:]) for name in dt_cfg["voltage_names"]
    ]

    seed = int(args.seed) if args.seed is not None else random.SystemRandom().randint(1, 2_000_000_000)
    sampler = CandidateSampler(dt_cfg, seed)
    round_v = float(dt_cfg["sampling"].get("dedupe_round_v", 0.0))
    seen = existing_keys(out_path, sampler.voltage_names, round_v)

    made = 0
    attempts = 0
    while made < args.n:
        attempts += 1
        if attempts > args.n * 200:
            raise RuntimeError("No pude generar suficientes candidatos únicos.")
        mode, free = sampler.sample()
        key = key_for(sampler.voltage_names, free, round_v)
        if key in seen and not args.include_duplicates:
            continue
        seen.add(key)
        full_voltages = full_voltage_vector(dt_cfg, free)
        if args.dry_run:
            print(f"{made + 1:04d} {mode} " + " ".join(f"{k}={free[k]:.6g}" for k in sampler.voltage_names))
            made += 1
            continue

        metrics, metadata = run_hackathon_fastadj(simion_cfg, full_voltages)
        row: dict[str, Any] = {
            "timestamp": datetime.now().isoformat(timespec="seconds"),
            "sample_mode": mode,
            "elapsed_seconds": metadata.get("elapsed_seconds"),
        }
        row.update({name: free[name] for name in sampler.voltage_names})
        row.update(flatten_metrics(metrics))
        append_row(out_path, row)
        contact = float(metrics.get("detector_contact_fraction") or metrics.get("transmission") or 0.0)
        th95 = metrics.get("terminal_angle_theta_p95_deg")
        th_text = "" if th95 is None else f" th95={float(th95):.3f}"
        print(f"{made + 1:04d}/{args.n} {mode} contact={100*contact:.2f}%{th_text} -> {out_path}")
        made += 1


if __name__ == "__main__":
    main()
