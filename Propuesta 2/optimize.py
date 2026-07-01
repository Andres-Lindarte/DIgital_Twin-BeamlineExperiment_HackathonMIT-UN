"""Optimizacion BO-GP de electrodos 1..4 mediante Optuna GPSampler."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import random
import re
import struct
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VENV_PYTHON = ROOT / ".venv" / "Scripts" / "python.exe"


def ensure_optuna_runtime() -> None:
    required_modules = ("optuna", "scipy", "torch")
    missing = [name for name in required_modules if importlib.util.find_spec(name) is None]
    if not missing:
        return
    if not VENV_PYTHON.is_file():
        raise SystemExit(
            f"Faltan modulos {', '.join(missing)}. Ejecute: python -m venv .venv && "
            ".\\.venv\\Scripts\\python -m pip install -r requirements-optuna.txt"
        )
    try:
        already_in_venv = Path(sys.executable).resolve() == VENV_PYTHON.resolve()
    except OSError:
        already_in_venv = False
    if already_in_venv:
        raise SystemExit(
            f"Entorno .venv incompleto; faltan: {', '.join(missing)}. "
            ".\\.venv\\Scripts\\python -m pip install -r requirements-optuna.txt"
        )
    completed = subprocess.run(
        [str(VENV_PYTHON), str(Path(__file__)), *sys.argv[1:]],
        cwd=ROOT,
        check=False,
    )
    raise SystemExit(completed.returncode)


ensure_optuna_runtime()

import optuna  # noqa: E402

from automation.simion_automation import run_simulation  # noqa: E402


XYZ_PATTERN = re.compile(
    r"xyz\(\s*(-?\d+(?:\.\d*)?),\s*(-?\d+(?:\.\d*)?),\s*(-?\d+(?:\.\d*)?)\)mm"
)

ELECTRODE_GROUPS = {
    "source": [1],
    "ground_pipe": [2],
    "einzel_1": [3, 4, 5],
    "einzel_2": [6, 7, 8],
    "bender": [9, 10, 11, 12],
    "ground_plates": [13, 14, 16, 17],
    "steering": [15, 18],
    "detector": [19],
}

ELECTRODE_TO_GROUP = {
    electrode: group
    for group, electrodes in ELECTRODE_GROUPS.items()
    for electrode in electrodes
}

STL_BOUNDS_CACHE: dict[tuple[str, float, float, float, float], list[dict[str, object]]] = {}


def load_config(path: Path) -> dict[str, object]:
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    required = {
        "study_name",
        "storage",
        "seed",
        "startup_trials",
        "stagnation_trials",
        "minimum_improvement",
        "repeats_per_trial",
        "theta_max_deg",
        "detector_radius_mm",
        "optimized_electrodes",
        "fixed_voltages",
        "voltage_bounds",
    }
    missing = required - config.keys()
    if missing:
        raise ValueError("Faltan opciones: " + ", ".join(sorted(missing)))
    if "baseline_repeats" in config and "sobol_trials" in config:
        expected = int(config["baseline_repeats"]) + int(config["sobol_trials"])
        if int(config["startup_trials"]) != expected:
            raise ValueError("startup_trials debe ser baseline_repeats + sobol_trials")
    return config


def completed_trials(study: optuna.Study) -> list[optuna.trial.FrozenTrial]:
    return [
        trial
        for trial in study.get_trials(deepcopy=False)
        if trial.state == optuna.trial.TrialState.COMPLETE and trial.value is not None
    ]


def stagnated(
    study: optuna.Study,
    patience: int,
    minimum_improvement: float,
    start_after: int = 0,
) -> bool:
    trials = completed_trials(study)
    if len(trials) < start_after + patience:
        return False
    best = float("-inf")
    last_improvement = -1
    for index, trial in enumerate(trials):
        value = float(trial.value)
        if value >= best + minimum_improvement:
            best = value
            last_improvement = index
    count_from = max(start_after, last_improvement + 1)
    return len(trials) - count_from >= patience


def print_status(study: optuna.Study) -> None:
    trials = completed_trials(study)
    print(f"Estudio: {study.study_name}")
    print(f"Corridas completas: {len(trials)}")
    if trials:
        best = study.best_trial
        voltages = best.user_attrs.get("voltages", {})
        metrics = best.user_attrs.get("metrics", {})
        transmission = float(
            best.user_attrs.get(
                "valid_transmission",
                metrics.get("transmission", best.value) if isinstance(metrics, dict) else best.value,
            )
        )
        guidance = float(best.user_attrs.get("guidance_score", 0.0))
        print(f"Mejor objetivo: {float(best.value):.6f}")
        print(f"Mejor transmision valida: {100 * transmission:.2f}%")
        print(f"Guia concentrica: {guidance:.6f}")
        print("Voltajes:", " ".join(f"{key}={value:.6g}" for key, value in voltages.items()))


def guidance_score(metrics: dict[str, object]) -> float:
    """Score suave 0..1 para romper empates cuando transmission es igual."""
    launched = float(metrics.get("ions_flown") or 0.0)
    if launched <= 0:
        return 0.0

    if "ions_lost" in metrics:
        # Progreso axial aproximado: perderse cerca del detector es más informativo
        # que morirse al inicio. Mantiene transmission como objetivo dominante.
        weights = {
            "loss_group_source": 0.05,
            "loss_group_ground_pipe": 0.10,
            "loss_group_einzel_1": 0.20,
            "loss_group_einzel_2": 0.35,
            "loss_group_bender": 0.55,
            "loss_group_ground_plates": 0.70,
            "loss_group_steering": 0.82,
            "loss_group_detector": 0.95,
        }
        weighted = 0.0
        for key, weight in weights.items():
            weighted += weight * float(metrics.get(key) or 0.0)
        weighted += 1.0 * float(metrics.get("ions_detected") or 0.0)
        group_score = max(0.0, min(1.0, weighted / launched))
        proximity = metrics.get("loss_detector_proximity_mean")
        if proximity is None:
            return group_score
        # Mezcla: conservar progreso por pieza, pero preferir pérdidas cerca
        # del detector real para evitar trayectorias patológicas "avanzadas".
        proximity_score = max(0.0, min(1.0, float(proximity)))
        e19_window_proximity = metrics.get("loss_E19_active_window_proximity_mean")
        e19_score = None
        if e19_window_proximity is not None:
            e19_score = (
                float(metrics.get("ions_detected") or 0.0)
                + float(metrics.get("loss_E19") or 0.0)
                * max(0.0, min(1.0, float(e19_window_proximity)))
            ) / launched
            e19_score = max(0.0, min(1.0, e19_score))
        real_bpm_score_raw = metrics.get("bpm_real_score")
        if real_bpm_score_raw is not None:
            real_bpm_score = max(0.0, min(1.0, float(real_bpm_score_raw)))
            if e19_score is not None:
                return (
                    0.20 * group_score
                    + 0.15 * proximity_score
                    + 0.45 * e19_score
                    + 0.20 * real_bpm_score
                )
            return 0.25 * group_score + 0.25 * proximity_score + 0.50 * real_bpm_score
        bpm_score_raw = metrics.get("bpm_detector_score")
        if bpm_score_raw is None:
            if e19_score is not None:
                return 0.25 * group_score + 0.25 * proximity_score + 0.50 * e19_score
            return 0.45 * group_score + 0.55 * proximity_score
        bpm_score = max(0.0, min(1.0, float(bpm_score_raw)))
        return 0.30 * group_score + 0.35 * proximity_score + 0.35 * bpm_score

    radius_weights = (1.0, 0.55, 0.25, 0.08)
    radius_counts = (
        float(metrics.get("ions_radius_le_detector") or 0.0),
        float(metrics.get("ions_radius_le_guidance_2") or 0.0),
        float(metrics.get("ions_radius_le_guidance_3") or 0.0),
        float(metrics.get("ions_radius_le_guidance_4") or 0.0),
    )
    radius_part = sum(
        weight * count for weight, count in zip(radius_weights, radius_counts)
    ) / (sum(radius_weights) * launched)
    angle_part = float(
        metrics.get("ions_theta_le_scaled_deg")
        or metrics.get("ions_theta_le_max_deg")
        or 0.0
    ) / launched
    score = 0.8 * radius_part + 0.2 * angle_part
    return max(0.0, min(1.0, score))


def parse_xyz_positions(text: str) -> list[tuple[float, float, float]]:
    """Extrae líneas SIMION tipo xyz(76, 75, 405)mm."""
    return [tuple(map(float, match)) for match in XYZ_PATTERN.findall(text)]


def in_box(
    point: tuple[float, float, float],
    box: dict[str, list[float] | tuple[float, float]],
) -> bool:
    x, y, z = point
    return (
        float(box["x"][0]) <= x <= float(box["x"][1])
        and float(box["y"][0]) <= y <= float(box["y"][1])
        and float(box["z"][0]) <= z <= float(box["z"][1])
    )


def mean(values: list[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def stdev(values: list[float]) -> float | None:
    if len(values) < 2:
        return None
    m = sum(values) / len(values)
    return (sum((value - m) ** 2 for value in values) / (len(values) - 1)) ** 0.5


def distance(
    a: tuple[float, float, float],
    b: tuple[float, float, float],
) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def distance_to_box(
    point: tuple[float, float, float],
    box: dict[str, list[float] | tuple[float, float]],
) -> float:
    x, y, z = point
    dx = max(float(box["x"][0]) - x, 0.0, x - float(box["x"][1]))
    dy = max(float(box["y"][0]) - y, 0.0, y - float(box["y"][1]))
    dz = max(float(box["z"][0]) - z, 0.0, z - float(box["z"][1]))
    return (dx * dx + dy * dy + dz * dz) ** 0.5


def read_stl_bounds(path: Path) -> tuple[float, float, float, float, float, float]:
    data = path.read_bytes()
    if len(data) < 84:
        raise ValueError(f"STL incompleto: {path}")
    triangles = struct.unpack_from("<I", data, 80)[0]
    expected = 84 + 50 * triangles
    if len(data) != expected:
        raise ValueError(f"STL no binario o corrupto: {path}")
    xmin = ymin = zmin = float("inf")
    xmax = ymax = zmax = float("-inf")
    for triangle in range(triangles):
        vertices = struct.unpack_from("<9f", data, 84 + triangle * 50 + 12)
        xs, ys, zs = vertices[0::3], vertices[1::3], vertices[2::3]
        xmin, xmax = min(xmin, *xs), max(xmax, *xs)
        ymin, ymax = min(ymin, *ys), max(ymax, *ys)
        zmin, zmax = min(zmin, *zs), max(zmax, *zs)
    return xmin, xmax, ymin, ymax, zmin, zmax


def load_electrode_bounds(
    directory: Path,
    margin_mm: float,
    offset_mm: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> list[dict[str, object]]:
    """Carga bounding boxes de electrode_*.stl en coordenadas del hackathon."""
    ox, oy, oz = offset_mm
    key = (str(directory.resolve()), float(margin_mm), float(ox), float(oy), float(oz))
    cached = STL_BOUNDS_CACHE.get(key)
    if cached is not None:
        return cached
    rows: list[dict[str, object]] = []
    for path in directory.glob("electrode_*.stl"):
        match = re.fullmatch(r"electrode_(\d+)\.stl", path.name, flags=re.IGNORECASE)
        if not match:
            continue
        electrode = int(match.group(1))
        xmin, xmax, ymin, ymax, zmin, zmax = read_stl_bounds(path)
        xmin, xmax = xmin + ox, xmax + ox
        ymin, ymax = ymin + oy, ymax + oy
        zmin, zmax = zmin + oz, zmax + oz
        rows.append(
            {
                "electrode": electrode,
                "group": ELECTRODE_TO_GROUP.get(electrode, "unknown"),
                "x_min": xmin - margin_mm,
                "x_max": xmax + margin_mm,
                "y_min": ymin - margin_mm,
                "y_max": ymax + margin_mm,
                "z_min": zmin - margin_mm,
                "z_max": zmax + margin_mm,
                "cx": 0.5 * (xmin + xmax),
                "cy": 0.5 * (ymin + ymax),
                "cz": 0.5 * (zmin + zmax),
            }
        )
    rows.sort(key=lambda row: int(row["electrode"]))
    STL_BOUNDS_CACHE[key] = rows
    return rows


def point_in_bounds(point: tuple[float, float, float], row: dict[str, object]) -> bool:
    x, y, z = point
    return (
        float(row["x_min"]) <= x <= float(row["x_max"])
        and float(row["y_min"]) <= y <= float(row["y_max"])
        and float(row["z_min"]) <= z <= float(row["z_max"])
    )


def center_distance2(point: tuple[float, float, float], row: dict[str, object]) -> float:
    x, y, z = point
    return (
        (x - float(row["cx"])) ** 2
        + (y - float(row["cy"])) ** 2
        + (z - float(row["cz"])) ** 2
    )


def classify_splats(
    positions: list[tuple[float, float, float]],
    hits: list[tuple[float, float, float]],
    electrode_bounds: list[dict[str, object]],
    detector_center: tuple[float, float, float] | None = None,
    detector_box: dict[str, list[float] | tuple[float, float]] | None = None,
    detector_distance_scale_mm: float = 220.0,
) -> dict[str, object]:
    """Clasifica posiciones terminales no-detectadas por electrodo/grupo."""
    hit_set = set(hits)
    losses = [point for point in positions if point not in hit_set]
    by_electrode = {f"loss_E{electrode}": 0 for electrode in range(1, 20)}
    points_by_electrode: dict[int, list[tuple[float, float, float]]] = {
        electrode: [] for electrode in range(1, 20)
    }
    by_group = {f"loss_group_{group}": 0 for group in sorted(ELECTRODE_GROUPS)}
    unknown = 0
    xs = [point[0] for point in losses]
    ys = [point[1] for point in losses]
    zs = [point[2] for point in losses]
    proximities: list[float] = []
    distances: list[float] = []
    for point in losses:
        if detector_center is not None:
            d = distance(point, detector_center)
            distances.append(d)
            proximities.append(__import__("math").exp(-d / detector_distance_scale_mm))
        candidates = [row for row in electrode_bounds if point_in_bounds(point, row)]
        if not candidates:
            unknown += 1
            continue
        row = min(candidates, key=lambda item: center_distance2(point, item))
        electrode = int(row["electrode"])
        group = str(row["group"])
        by_electrode[f"loss_E{electrode}"] += 1
        points_by_electrode[electrode].append(point)
        by_group[f"loss_group_{group}"] = by_group.get(f"loss_group_{group}", 0) + 1
    electrode_stats: dict[str, object] = {}
    if detector_center is not None:
        for electrode, electrode_points in points_by_electrode.items():
            if not electrode_points:
                continue
            electrode_xs = [point[0] for point in electrode_points]
            electrode_ys = [point[1] for point in electrode_points]
            electrode_zs = [point[2] for point in electrode_points]
            electrode_distances = [
                distance(point, detector_center) for point in electrode_points
            ]
            prefix = f"loss_E{electrode}"
            electrode_stats.update({
                f"{prefix}_mean_x": mean(electrode_xs),
                f"{prefix}_mean_y": mean(electrode_ys),
                f"{prefix}_mean_z": mean(electrode_zs),
                f"{prefix}_min_x": min(electrode_xs),
                f"{prefix}_max_x": max(electrode_xs),
                f"{prefix}_min_y": min(electrode_ys),
                f"{prefix}_max_y": max(electrode_ys),
                f"{prefix}_min_z": min(electrode_zs),
                f"{prefix}_max_z": max(electrode_zs),
                f"{prefix}_sigma_x": stdev(electrode_xs),
                f"{prefix}_sigma_y": stdev(electrode_ys),
                f"{prefix}_sigma_z": stdev(electrode_zs),
                f"{prefix}_detector_distance_mean_mm": mean(electrode_distances),
            })
    if detector_box is not None and points_by_electrode.get(19):
        import math

        e19_points = points_by_electrode[19]
        e19_distances = [distance_to_box(point, detector_box) for point in e19_points]
        scale = 12.0
        e19_proximity = [math.exp(-d / scale) for d in e19_distances]
        x_low, x_high = float(detector_box["x"][0]), float(detector_box["x"][1])
        y_low, y_high = float(detector_box["y"][0]), float(detector_box["y"][1])
        z_low, z_high = float(detector_box["z"][0]), float(detector_box["z"][1])
        electrode_stats.update({
            "loss_E19_active_window_distance_mean_mm": mean(e19_distances),
            "loss_E19_active_window_distance_min_mm": min(e19_distances),
            "loss_E19_active_window_distance_max_mm": max(e19_distances),
            "loss_E19_active_window_proximity_mean": mean(e19_proximity),
            "loss_E19_miss_x_low": sum(1 for x, _, _ in e19_points if x < x_low),
            "loss_E19_miss_x_high": sum(1 for x, _, _ in e19_points if x > x_high),
            "loss_E19_miss_y_low": sum(1 for _, y, _ in e19_points if y < y_low),
            "loss_E19_miss_y_high": sum(1 for _, y, _ in e19_points if y > y_high),
            "loss_E19_miss_z_low": sum(1 for _, _, z in e19_points if z < z_low),
            "loss_E19_miss_z_high": sum(1 for _, _, z in e19_points if z > z_high),
        })
    return {
        "ions_lost": len(losses),
        "loss_unknown": unknown,
        "loss_mean_x": mean(xs),
        "loss_mean_y": mean(ys),
        "loss_mean_z": mean(zs),
        "loss_detector_distance_mean_mm": mean(distances),
        "loss_detector_proximity_mean": mean(proximities),
        **by_electrode,
        **electrode_stats,
        **by_group,
    }


def detector_local_bpm(
    positions: list[tuple[float, float, float]],
    detector_center: tuple[float, float, float],
    launched: int,
    z_window_mm: float = 60.0,
    core_rx_mm: float = 10.0,
    core_ry_mm: float = 10.0,
    side_rx_mm: float = 14.0,
    side_ry_mm: float = 14.0,
    side_offset_mm: float = 10.0,
) -> dict[str, object]:
    """Monitor local en plano del detector usando terminal xyz.

    Cuenta 5 elipses superpuestas cerca del detector: centro, izquierda,
    derecha, arriba y abajo. Es deliberadamente suave: sirve como diagnóstico
    de por qué se falla cerca del detector.
    """
    x0, y0, z0 = detector_center

    def in_ellipse(
        point: tuple[float, float, float],
        cx: float,
        cy: float,
        rx: float,
        ry: float,
    ) -> bool:
        if rx <= 0 or ry <= 0:
            return False
        x, y, _ = point
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0

    near = [
        point for point in positions
        if abs(point[2] - z0) <= z_window_mm
    ]
    center = [
        point for point in near
        if in_ellipse(point, x0, y0, core_rx_mm, core_ry_mm)
    ]
    left = [
        point for point in near
        if in_ellipse(point, x0 - side_offset_mm, y0, side_rx_mm, side_ry_mm)
    ]
    right = [
        point for point in near
        if in_ellipse(point, x0 + side_offset_mm, y0, side_rx_mm, side_ry_mm)
    ]
    down = [
        point for point in near
        if in_ellipse(point, x0, y0 - side_offset_mm, side_rx_mm, side_ry_mm)
    ]
    up = [
        point for point in near
        if in_ellipse(point, x0, y0 + side_offset_mm, side_rx_mm, side_ry_mm)
    ]

    # Score por ion, evitando doble conteo por superposición.
    score_sum = 0.0
    for point in positions:
        if abs(point[2] - z0) > z_window_mm:
            continue
        point_score = 0.20
        if in_ellipse(point, x0 - side_offset_mm, y0, side_rx_mm, side_ry_mm):
            point_score = max(point_score, 0.65)
        if in_ellipse(point, x0 + side_offset_mm, y0, side_rx_mm, side_ry_mm):
            point_score = max(point_score, 0.65)
        if in_ellipse(point, x0, y0 - side_offset_mm, side_rx_mm, side_ry_mm):
            point_score = max(point_score, 0.65)
        if in_ellipse(point, x0, y0 + side_offset_mm, side_rx_mm, side_ry_mm):
            point_score = max(point_score, 0.65)
        if in_ellipse(point, x0, y0, core_rx_mm, core_ry_mm):
            point_score = max(point_score, 1.0)
        score_sum += point_score

    near_xs = [point[0] for point in near]
    near_ys = [point[1] for point in near]
    offset_x = None if not near_xs else mean(near_xs) - x0  # type: ignore[operator]
    offset_y = None if not near_ys else mean(near_ys) - y0  # type: ignore[operator]
    left_right = (len(right) - len(left)) / launched if launched > 0 else 0.0
    up_down = (len(up) - len(down)) / launched if launched > 0 else 0.0

    return {
        "bpm_detector_near": len(near),
        "bpm_detector_center": len(center),
        "bpm_detector_left": len(left),
        "bpm_detector_right": len(right),
        "bpm_detector_down": len(down),
        "bpm_detector_up": len(up),
        "bpm_detector_score": score_sum / launched if launched > 0 else 0.0,
        "bpm_detector_offset_x_mm": offset_x,
        "bpm_detector_offset_y_mm": offset_y,
        "bpm_detector_left_right_balance": left_right,
        "bpm_detector_up_down_balance": up_down,
    }


def parse_bpm_real_summary(text: str) -> dict[str, object]:
    """Parsea la linea BPM_REAL_SUMMARY emitida por SimpleSetUp.lua."""
    summary_line = None
    for line in text.splitlines():
        if line.startswith("BPM_REAL_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}

    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metric_key = f"bpm_real_{key}"
        try:
            number = float(value)
        except ValueError:
            metrics[metric_key] = value
            continue
        if number.is_integer():
            metrics[metric_key] = int(number)
        else:
            metrics[metric_key] = number
    return metrics


def parse_detector_valid_summary(text: str) -> dict[str, object]:
    """Parsea la linea DETECTOR_VALID_SUMMARY emitida por SimpleSetUp.lua."""
    summary_line = None
    for line in text.splitlines():
        if line.startswith("DETECTOR_VALID_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}

    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metric_key = f"detector_valid_{key}"
        try:
            number = float(value)
        except ValueError:
            metrics[metric_key] = value
            continue
        if number.is_integer():
            metrics[metric_key] = int(number)
        else:
            metrics[metric_key] = number
    return metrics


def parse_detector_face_summary(text: str) -> dict[str, object]:
    summary_line = None
    for line in text.splitlines():
        if line.startswith("DETECTOR_FACE_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}
    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metrics[f"detector_face_{key}"] = int(float(value))
    return metrics


def parse_terminal_angle_summary(text: str) -> dict[str, object]:
    summary_line = None
    for line in text.splitlines():
        if line.startswith("TERMINAL_ANGLE_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}
    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metric_key = f"terminal_angle_{key}"
        number = float(value)
        metrics[metric_key] = int(number) if number.is_integer() else number
    return metrics


def parse_detector_contact_angle_summary(text: str) -> dict[str, object]:
    summary_line = None
    for line in text.splitlines():
        if line.startswith("DETECTOR_CONTACT_ANGLE_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}
    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metric_key = f"detector_contact_angle_{key}"
        number = float(value)
        metrics[metric_key] = int(number) if number.is_integer() else number
    return metrics


def parse_detector_contact_speed_summary(text: str) -> dict[str, object]:
    summary_line = None
    for line in text.splitlines():
        if line.startswith("DETECTOR_CONTACT_SPEED_SUMMARY "):
            summary_line = line
    if summary_line is None:
        return {}
    metrics: dict[str, object] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([^\s]+)", summary_line):
        metric_key = f"detector_contact_speed_{key}"
        number = float(value)
        metrics[metric_key] = int(number) if number.is_integer() else number
    return metrics


def run_hackathon_fastadj(
    config: dict[str, object],
    voltages: dict[str, float],
) -> tuple[dict[str, object], dict[str, object]]:
    """Corre el beamline oficial usando fastadj + fly y parsea hits xyz."""
    simion_exe = (ROOT / str(config.get("simion_exe", "SIMION/simion.exe"))).resolve()
    iob_path = (ROOT / str(config["iob_path"])).resolve()
    pa0_path = (ROOT / str(config["pa0_path"])).resolve()
    particles_raw = config.get("particles_path")
    particles_path = (ROOT / str(particles_raw)).resolve() if particles_raw else None
    timeout_seconds = float(config.get("timeout_seconds", 600.0))
    max_electrode = int(config.get("max_electrode", 19))

    if not simion_exe.is_file():
        raise FileNotFoundError(f"No existe SIMION: {simion_exe}")
    if not iob_path.is_file():
        raise FileNotFoundError(f"No existe IOB: {iob_path}")
    if not pa0_path.is_file():
        raise FileNotFoundError(f"No existe PA0 refinado: {pa0_path}")
    if particles_path is not None and not particles_path.is_file():
        raise FileNotFoundError(f"No existe FLY2: {particles_path}")

    voltage_by_number: dict[int, float] = {}
    for name, value in voltages.items():
        match = re.fullmatch(r"V?(\d+)", str(name))
        if not match:
            raise ValueError(f"Nombre de voltaje inválido: {name}")
        voltage_by_number[int(match.group(1))] = float(value)
    for electrode in range(1, max_electrode + 1):
        voltage_by_number.setdefault(electrode, 0.0)

    settings = ",".join(
        f"{electrode}={voltage_by_number[electrode]:.17g}"
        for electrode in range(1, max_electrode + 1)
    )
    fastadj_command = [
        str(simion_exe),
        "--nogui",
        "fastadj",
        str(pa0_path),
        settings,
    ]
    enable_real_bpm = bool(config.get("enable_real_bpm", False))
    fly_command = [
        str(simion_exe),
        "--nogui",
        "fly",
        "--retain-trajectories=0",
        "--restore-potential=0",
        "--programs=1" if enable_real_bpm else "--programs=0",
    ]
    if enable_real_bpm:
        real_bpm_config = dict(config.get("real_bpm", {}))
        detector_valid_config = dict(config.get("detector_valid", {}))
        detector_box_for_lua = dict(config.get("detector_box", {}))
        bpm_adjustables = {
            "bpm_enable": 1,
            "bpm_z_mm": float(real_bpm_config.get("z_mm", 390.0)),
            "bpm_center_x_mm": float(real_bpm_config.get("center_x_mm", 76.0)),
            "bpm_center_y_mm": float(real_bpm_config.get("center_y_mm", 76.0)),
            "bpm_core_rx_mm": float(real_bpm_config.get("core_rx_mm", 9.0)),
            "bpm_core_ry_mm": float(real_bpm_config.get("core_ry_mm", 9.0)),
            "bpm_side_rx_mm": float(real_bpm_config.get("side_rx_mm", 15.0)),
            "bpm_side_ry_mm": float(real_bpm_config.get("side_ry_mm", 15.0)),
            "bpm_side_offset_mm": float(real_bpm_config.get("side_offset_mm", 10.0)),
            "bpm_print_hits": int(real_bpm_config.get("print_hits", 0)),
            "detector_valid_enable": int(detector_valid_config.get("enabled", 1)),
            "detector_front_z_mm": float(
                detector_valid_config.get(
                    "front_z_mm",
                    float(detector_box_for_lua.get("z", [403.0, 407.0])[0])
                    if detector_box_for_lua else 403.0,
                )
            ),
            "detector_x_min_mm": float(
                detector_valid_config.get(
                    "x_min_mm",
                    float(detector_box_for_lua.get("x", [70.0, 82.0])[0])
                    if detector_box_for_lua else 70.0,
                )
            ),
            "detector_x_max_mm": float(
                detector_valid_config.get(
                    "x_max_mm",
                    float(detector_box_for_lua.get("x", [70.0, 82.0])[1])
                    if detector_box_for_lua else 82.0,
                )
            ),
            "detector_y_min_mm": float(
                detector_valid_config.get(
                    "y_min_mm",
                    float(detector_box_for_lua.get("y", [70.0, 83.0])[0])
                    if detector_box_for_lua else 70.0,
                )
            ),
            "detector_y_max_mm": float(
                detector_valid_config.get(
                    "y_max_mm",
                    float(detector_box_for_lua.get("y", [70.0, 83.0])[1])
                    if detector_box_for_lua else 83.0,
                )
            ),
            "detector_theta_max_deg": float(detector_valid_config.get("theta_max_deg", 180.0)),
            "detector_require_angle": int(detector_valid_config.get("require_angle", 0)),
            "detector_z_margin_mm": float(detector_valid_config.get("z_margin_mm", 2.0)),
        }
        for name, value in bpm_adjustables.items():
            fly_command.extend(["--adjustable", f"{name}={value:.17g}"])
    if particles_path is not None:
        fly_command.extend(["--particles", str(particles_path)])
    fly_command.append(str(iob_path))

    started = __import__("time").monotonic()
    fastadj = subprocess.run(
        fastadj_command,
        cwd=iob_path.parent,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
        check=False,
    )
    if fastadj.returncode != 0:
        raise RuntimeError("fastadj falló:\n" + fastadj.stdout[-4000:])

    fly = subprocess.run(
        fly_command,
        cwd=iob_path.parent,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
        check=False,
    )
    elapsed = __import__("time").monotonic() - started
    if fly.returncode != 0:
        raise RuntimeError("fly falló:\n" + fly.stdout[-4000:])

    positions = parse_xyz_positions(fly.stdout)
    detector_box = dict(config.get("detector_box", {}))
    hits = [point for point in positions if not detector_box or in_box(point, detector_box)]
    launched = int(config.get("ions_launched", 500))
    ys = [point[1] for point in hits]
    zs = [point[2] for point in hits]
    metrics: dict[str, object] = {
        "ions_flown": launched,
        "ions_reported": len(positions),
        "ions_detected": len(hits),
        "ions_detected_geometric": len(hits),
        "transmission": len(hits) / launched if launched > 0 else 0.0,
        "transmission_geometric": len(hits) / launched if launched > 0 else 0.0,
        "transmission_percent": 100.0 * len(hits) / launched if launched > 0 else 0.0,
        "centroid_y_mm": mean(ys),
        "centroid_z_mm": mean(zs),
        "sigma_y_mm": stdev(ys),
        "sigma_z_mm": stdev(zs),
        "spread_yz_mm": ((stdev(ys) or 0.0) + (stdev(zs) or 0.0)) if hits else None,
    }
    if enable_real_bpm:
        bpm_metrics = parse_bpm_real_summary(fly.stdout)
        if not bpm_metrics:
            raise RuntimeError(
                "SIMION no emitio BPM_REAL_SUMMARY. "
                "Probablemente SimpleSetUp.lua no esta adjunto/cargado como programa del workbench."
            )
        metrics.update(bpm_metrics)
        detector_metrics = parse_detector_valid_summary(fly.stdout)
        if bool(config.get("use_detector_valid_as_transmission", False)):
            if not detector_metrics:
                raise RuntimeError(
                    "SIMION no emitio DETECTOR_VALID_SUMMARY. "
                    "No puedo validar hits frontales del detector."
                )
            metrics.update(detector_metrics)
            valid_hits = int(metrics.get("detector_valid_valid") or 0)
            metrics["ions_detected"] = valid_hits
            metrics["transmission"] = valid_hits / launched if launched > 0 else 0.0
            metrics["transmission_percent"] = (
                100.0 * valid_hits / launched if launched > 0 else 0.0
            )
        elif detector_metrics:
            metrics.update(detector_metrics)
        face_metrics = parse_detector_face_summary(fly.stdout)
        if face_metrics:
            metrics.update(face_metrics)
        terminal_angle_metrics = parse_terminal_angle_summary(fly.stdout)
        if terminal_angle_metrics:
            metrics.update(terminal_angle_metrics)
        detector_contact_angle_metrics = parse_detector_contact_angle_summary(fly.stdout)
        if detector_contact_angle_metrics:
            metrics.update(detector_contact_angle_metrics)
            active_count = int(metrics.get("detector_contact_angle_count") or 0)
            forward_count = int(metrics.get("detector_contact_angle_forward") or 0)
            metrics["detector_active_contact_count"] = active_count
            metrics["detector_active_contact_fraction"] = (
                active_count / launched if launched > 0 else 0.0
            )
            metrics["detector_active_contact_percent"] = (
                100.0 * active_count / launched if launched > 0 else 0.0
            )
            metrics["detector_active_forward_fraction"] = (
                forward_count / active_count if active_count > 0 else 0.0
            )
        detector_contact_speed_metrics = parse_detector_contact_speed_summary(fly.stdout)
        if detector_contact_speed_metrics:
            metrics.update(detector_contact_speed_metrics)
    if bool(config.get("enable_splat_map", False)):
        stl_directory = (ROOT / str(config.get("stl_directory", iob_path.parent))).resolve()
        margin = float(config.get("splat_match_margin_mm", 3.0))
        raw_offset = list(config.get("stl_offset_mm", [0.0, 0.0, 0.0]))
        if len(raw_offset) != 3:
            raise ValueError("stl_offset_mm debe tener tres valores [x,y,z]")
        offset = (float(raw_offset[0]), float(raw_offset[1]), float(raw_offset[2]))
        bounds = load_electrode_bounds(stl_directory, margin, offset)
        raw_center = config.get("detector_center_mm", [76.0, 76.0, 405.0])
        center_values = list(raw_center)
        if len(center_values) != 3:
            raise ValueError("detector_center_mm debe tener tres valores [x,y,z]")
        detector_center = (
            float(center_values[0]),
            float(center_values[1]),
            float(center_values[2]),
        )
        metrics.update(
            classify_splats(
                positions,
                hits,
                bounds,
                detector_center=detector_center,
                detector_box=detector_box,
                detector_distance_scale_mm=float(
                    config.get("detector_distance_scale_mm", 220.0)
                ),
            )
        )
        detector_contact_count = int(metrics.get("ions_detected_geometric") or 0) + int(
            metrics.get("loss_E19") or 0
        )
        metrics["detector_contact_count"] = detector_contact_count
        metrics["detector_contact_fraction"] = (
            detector_contact_count / launched if launched > 0 else 0.0
        )
        metrics["detector_contact_percent"] = (
            100.0 * detector_contact_count / launched if launched > 0 else 0.0
        )
        if bool(config.get("enable_detector_bpm", False)):
            bpm_config = dict(config.get("detector_bpm", {}))
            metrics.update(
                detector_local_bpm(
                    positions,
                    detector_center=detector_center,
                    launched=launched,
                    z_window_mm=float(bpm_config.get("z_window_mm", 60.0)),
                    core_rx_mm=float(bpm_config.get("core_rx_mm", 10.0)),
                    core_ry_mm=float(bpm_config.get("core_ry_mm", 10.0)),
                    side_rx_mm=float(bpm_config.get("side_rx_mm", 14.0)),
                    side_ry_mm=float(bpm_config.get("side_ry_mm", 14.0)),
                    side_offset_mm=float(bpm_config.get("side_offset_mm", 10.0)),
                )
            )
    metadata = {
        "elapsed_seconds": elapsed,
        "simion_exe": str(simion_exe),
        "iob": str(iob_path),
        "pa0": str(pa0_path),
        "particles": str(particles_path) if particles_path else None,
        "fastadj_command": fastadj_command,
        "fly_command": fly_command,
        "stdout_tail": fly.stdout[-4000:],
    }
    return metrics, metadata


def configured_bounds(config: dict[str, object]) -> dict[str, tuple[float, float]]:
    return {
        str(name): (float(values[0]), float(values[1]))
        for name, values in dict(config["voltage_bounds"]).items()
    }


def waiting_trials(study: optuna.Study) -> list[optuna.trial.FrozenTrial]:
    return [
        trial
        for trial in study.get_trials(deepcopy=False)
        if trial.state == optuna.trial.TrialState.WAITING
    ]


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def enqueue_local_refinement(study: optuna.Study, config: dict[str, object]) -> None:
    local = dict(config.get("local_refinement", {}))
    if not local.get("enabled", False):
        return
    trials = completed_trials(study)
    if not trials:
        return

    best = study.best_trial
    trigger_min = float(local.get("trigger_min_value", 0.01))
    if best.value is None or float(best.value) < trigger_min:
        return

    pending = waiting_trials(study)
    max_pending = int(local.get("max_pending", 24))
    if len(pending) >= max_pending:
        return

    refined_key = "local_refined_best_trial"
    if int(study.user_attrs.get(refined_key, -1)) == int(best.number):
        return

    names = [f"V{int(value)}" for value in config.get("optimized_electrodes", [])]
    bounds = configured_bounds(config)
    center = {name: float(best.params[name]) for name in names}
    radii_config = dict(local.get("radii", {}))
    min_radii_config = dict(local.get("min_radii", {}))
    batch = int(study.user_attrs.get("local_refinement_batches", 0))
    shrink = float(local.get("shrink_per_batch", 0.7))

    radii: dict[str, float] = {}
    for name in names:
        low, high = bounds[name]
        default_radius = 0.08 * (high - low)
        radius = float(radii_config.get(name, default_radius)) * (shrink ** batch)
        min_radius = float(min_radii_config.get(name, 0.01 * (high - low)))
        radii[name] = max(radius, min_radius)

    rng = random.Random(int(config["seed"]) + 1009 * int(best.number) + 9176 * batch)
    candidates: list[dict[str, float]] = []
    n = int(local.get("candidates_per_trigger", 12))
    for index in range(n):
        candidate = dict(center)
        if index < 2 * len(names):
            name = names[index // 2]
            sign = 1.0 if index % 2 == 0 else -1.0
            low, high = bounds[name]
            candidate[name] = clamp(center[name] + sign * radii[name], low, high)
        else:
            for name in names:
                low, high = bounds[name]
                candidate[name] = clamp(
                    center[name] + rng.uniform(-1.0, 1.0) * radii[name],
                    low,
                    high,
                )
        candidates.append(candidate)

    for candidate in candidates[: max(0, max_pending - len(pending))]:
        study.enqueue_trial(candidate, skip_if_exists=True)

    study.set_user_attr(refined_key, int(best.number))
    study.set_user_attr("local_refinement_batches", batch + 1)
    print(
        f"Refinamiento local encolado alrededor de trial {best.number}: "
        + " ".join(f"{name}+/-{radii[name]:.4g}" for name in names)
    )


def enqueue_startup_trials(study: optuna.Study, config: dict[str, object]) -> None:
    if study.trials:
        return
    if config.get("startup_candidates"):
        for candidate in list(config["startup_candidates"]):
            study.enqueue_trial({
                name: float(value)
                for name, value in dict(candidate).items()
            })
    elif config.get("startup_voltages"):
        baseline = {
            name: float(value)
            for name, value in dict(config["startup_voltages"]).items()
        }
        for _ in range(int(config.get("baseline_repeats", 1))):
            study.enqueue_trial(baseline)


def cmaes_sampler(config: dict[str, object]) -> optuna.samplers.CmaEsSampler:
    cma = dict(config.get("cmaes", {}))
    source_trials = load_cmaes_source_trials(config)
    if source_trials:
        print(f"CMA-ES warm-start nativo: {len(source_trials)} source_trials")
        return optuna.samplers.CmaEsSampler(
            n_startup_trials=int(cma.get("n_startup_trials", 1)),
            independent_sampler=optuna.samplers.RandomSampler(seed=int(config["seed"])),
            warn_independent_sampling=False,
            seed=int(config["seed"]),
            popsize=int(cma["popsize"]) if "popsize" in cma else None,
            with_margin=bool(cma.get("with_margin", False)),
            lr_adapt=bool(cma.get("lr_adapt", False)),
            source_trials=source_trials,
        )
    x0_source = dict(cma.get("x0") or config.get("startup_voltages", {}))
    x0 = {name: float(value) for name, value in x0_source.items()}
    return optuna.samplers.CmaEsSampler(
        x0=x0,
        sigma0=float(cma.get("sigma0", 10.0)),
        n_startup_trials=int(cma.get("n_startup_trials", 1)),
        independent_sampler=optuna.samplers.RandomSampler(seed=int(config["seed"])),
        warn_independent_sampling=False,
        seed=int(config["seed"]),
        popsize=int(cma["popsize"]) if "popsize" in cma else None,
        with_margin=bool(cma.get("with_margin", False)),
        lr_adapt=bool(cma.get("lr_adapt", False)),
    )


def nsga2_sampler(config: dict[str, object]) -> optuna.samplers.NSGAIISampler:
    ga = dict(config.get("nsga2", {}))
    return optuna.samplers.NSGAIISampler(
        population_size=int(ga.get("population_size", 24)),
        mutation_prob=(
            None if ga.get("mutation_prob") is None else float(ga["mutation_prob"])
        ),
        crossover_prob=float(ga.get("crossover_prob", 0.9)),
        swapping_prob=float(ga.get("swapping_prob", 0.5)),
        seed=int(config["seed"]),
    )


def botorch_sampler(config: dict[str, object]):
    from optuna_integration import BoTorchSampler

    bo = dict(config.get("botorch", {}))
    independent = optuna.samplers.QMCSampler(
        qmc_type="sobol",
        scramble=True,
        seed=int(config["seed"]),
        warn_independent_sampling=False,
    )
    return BoTorchSampler(
        n_startup_trials=int(bo.get("n_startup_trials", config.get("startup_trials", 30))),
        independent_sampler=independent,
        consider_running_trials=bool(bo.get("consider_running_trials", False)),
        seed=int(config["seed"]),
    )


def trial_has_params_in_bounds(
    trial: optuna.trial.FrozenTrial,
    names: list[str],
    bounds: dict[str, tuple[float, float]],
) -> bool:
    if not all(name in trial.params for name in names):
        return False
    for name in names:
        value = float(trial.params[name])
        low, high = bounds[name]
        if value < low or value > high:
            return False
    return True


def load_cmaes_source_trials(config: dict[str, object]) -> list[optuna.trial.FrozenTrial]:
    cma = dict(config.get("cmaes", {}))
    source = dict(cma.get("source_trials", {}))
    if not source.get("enabled", False):
        return []
    names = [f"V{int(value)}" for value in config.get("optimized_electrodes", [])]
    bnds = configured_bounds(config)
    prefix = str(source.get("study_prefix", ""))
    exclude_current = bool(source.get("exclude_current_study", True))
    current_study = str(config["study_name"])
    rows: list[optuna.trial.FrozenTrial] = []
    summaries = optuna.get_all_study_summaries(storage=str(config["storage"]))
    for summary in summaries:
        if exclude_current and summary.study_name == current_study:
            continue
        if prefix and not summary.study_name.startswith(prefix):
            continue
        study = optuna.load_study(
            study_name=summary.study_name,
            storage=str(config["storage"]),
        )
        rows.extend(
            trial
            for trial in completed_trials(study)
            if trial_has_params_in_bounds(trial, names, bnds)
        )
    min_value = float(source.get("min_value", float("-inf")))
    rows = [trial for trial in rows if float(trial.value) >= min_value]
    rows.sort(key=lambda trial: float(trial.value), reverse=True)
    max_trials = int(source.get("max_trials", 30))
    return rows[:max_trials]


def build_objective(config: dict[str, object]):
    repeats = int(config["repeats_per_trial"])
    aux_weight = float(config.get("objective_aux_weight", 0.005))
    transmission_weight = float(config.get("objective_transmission_weight", 1.0))
    voltage_cost_weight = float(config.get("voltage_cost_weight", 0.0))
    voltage_boundary_weight = float(config.get("voltage_boundary_weight", 0.0))
    voltage_cost_scale = float(config.get("voltage_cost_scale", 1000.0))
    voltage_comfort_limit = float(config.get("voltage_comfort_limit", 500.0))
    voltage_hard_limit = float(config.get("voltage_hard_limit", 1000.0))
    optimized = [int(value) for value in config.get("optimized_electrodes", [1, 2, 3, 4])]
    fixed = {
        str(name): float(value)
        for name, value in dict(config.get("fixed_voltages", {})).items()
    }
    bounds = {
        str(name): [float(value) for value in values]
        for name, values in dict(config["voltage_bounds"]).items()
    }
    if any(electrode < 1 or electrode > 22 for electrode in optimized):
        raise ValueError("Este ensayo solo admite electrodos 1..22")
    if any(f"V{electrode}" in fixed for electrode in optimized):
        raise ValueError("Un electrodo no puede ser fijo y optimizado")
    simulation_mode = str(config.get("simulation_mode", "legacy_lua")).lower()

    def objective(trial: optuna.Trial) -> float:
        voltages = dict(fixed)
        voltages.update({
            f"V{electrode}": trial.suggest_float(
                f"V{electrode}", *bounds[f"V{electrode}"]
            )
            for electrode in optimized
        })
        max_electrode = int(config.get("max_electrode", 22))
        for electrode in range(1, max_electrode + 1):
            voltages.setdefault(f"V{electrode}", 0.0)
        voltages = dict(sorted(voltages.items()))
        trial.set_user_attr("voltages", voltages)
        values: list[float] = []
        guidance_values: list[float] = []
        metrics_last: dict[str, object] = {}
        for repeat in range(repeats):
            if simulation_mode == "hackathon_fastadj":
                metrics, metadata = run_hackathon_fastadj(config, voltages)
            else:
                report = ROOT / "automation" / "runtime" / (
                    f"optuna_trial_{trial.number}_repeat_{repeat}.csv"
                )
                adjustables = {
                    "group_c_only": 1.0,
                    "detector_theta_max_deg": float(config["theta_max_deg"]),
                    "detector_radius_mm": float(config["detector_radius_mm"]),
                    "detector_guidance_radius_2_mm": float(
                        config.get("detector_guidance_radius_2_mm", 20.0)
                    ),
                    "detector_guidance_radius_3_mm": float(
                        config.get("detector_guidance_radius_3_mm", 35.0)
                    ),
                    "detector_guidance_radius_4_mm": float(
                        config.get("detector_guidance_radius_4_mm", 60.0)
                    ),
                    **voltages,
                }
                try:
                    _, metrics, metadata = run_simulation(
                        ROOT / "SIMION" / "simion.exe",
                        ROOT / "exportado" / "experimento.iob",
                        report,
                        recording_path=ROOT / "exportado" / "deteccion_x455.rec",
                        particles_path=ROOT / "exportado" / "pruebaSimple41.fly2",
                        adjustables=adjustables,
                    )
                finally:
                    report.unlink(missing_ok=True)
            values.append(float(metrics["transmission"]))
            guidance_values.append(
                float(metrics.get("guidance_score", guidance_score(metrics)))
            )
            metrics_last = metrics
            trial.set_user_attr("elapsed_seconds", metadata["elapsed_seconds"])

        transmission = sum(values) / len(values)
        guidance = sum(guidance_values) / len(guidance_values)
        optimized_voltage_values = [
            abs(float(voltages[f"V{electrode}"])) for electrode in optimized
        ]
        voltage_l2_cost = (
            sum((value / voltage_cost_scale) ** 2 for value in optimized_voltage_values)
            / len(optimized_voltage_values)
            if optimized_voltage_values
            else 0.0
        )
        voltage_boundary_cost = (
            sum(
                max(0.0, (value - voltage_comfort_limit) / (voltage_hard_limit - voltage_comfort_limit)) ** 2
                for value in optimized_voltage_values
            )
            / len(optimized_voltage_values)
            if optimized_voltage_values and voltage_hard_limit > voltage_comfort_limit
            else 0.0
        )
        voltage_penalty = (
            voltage_cost_weight * voltage_l2_cost
            + voltage_boundary_weight * voltage_boundary_cost
        )
        score = transmission_weight * transmission + aux_weight * guidance - voltage_penalty
        front_score = None
        angle_quality_score = None
        if str(config.get("objective_mode", "")).lower() == "front_guided":
            launched = float(metrics_last.get("ions_flown") or 0.0)
            if launched <= 0:
                launched = 1.0
            front_fraction = float(metrics_last.get("detector_valid_valid") or 0.0) / launched
            zmin_fraction = float(metrics_last.get("detector_face_z_min") or 0.0) / launched
            geometric_fraction = float(
                metrics_last.get("transmission_geometric", metrics_last.get("transmission", 0.0))
                or 0.0
            )
            bpm_center_fraction = float(metrics_last.get("bpm_real_center") or 0.0) / launched
            bpm_score = float(metrics_last.get("bpm_real_score") or 0.0)
            wrong_side_fraction = float(metrics_last.get("detector_valid_wrong_side") or 0.0) / launched
            lateral_fraction = (
                float(metrics_last.get("detector_face_x_min") or 0.0)
                + float(metrics_last.get("detector_face_x_max") or 0.0)
                + float(metrics_last.get("detector_face_y_min") or 0.0)
                + float(metrics_last.get("detector_face_y_max") or 0.0)
                + float(metrics_last.get("detector_face_z_max") or 0.0)
            ) / launched
            front_cfg = dict(config.get("front_guided_weights", {}))
            front_score = (
                float(front_cfg.get("front", 5.0)) * front_fraction
                + float(front_cfg.get("zmin", 1.2)) * zmin_fraction
                + float(front_cfg.get("bpm_center", 0.9)) * bpm_center_fraction
                + float(front_cfg.get("geometric", 0.45)) * geometric_fraction
                + float(front_cfg.get("bpm_score", 0.20)) * bpm_score
                - float(front_cfg.get("wrong_side", 1.5)) * wrong_side_fraction
                - float(front_cfg.get("lateral", 0.8)) * lateral_fraction
            )
            score = front_score - voltage_penalty
        elif str(config.get("objective_mode", "")).lower() == "detector_contact":
            contact_fraction = float(metrics_last.get("detector_contact_fraction") or 0.0)
            geometric_fraction = float(
                metrics_last.get("transmission_geometric", metrics_last.get("transmission", 0.0))
                or 0.0
            )
            e19_window_proximity = float(
                metrics_last.get("loss_E19_active_window_proximity_mean") or 0.0
            )
            contact_cfg = dict(config.get("detector_contact_weights", {}))
            contact_score = (
                float(contact_cfg.get("contact", 1.0)) * contact_fraction
                + float(contact_cfg.get("geometric", 0.10)) * geometric_fraction
                + float(contact_cfg.get("e19_window", 0.05)) * e19_window_proximity
            )
            score = contact_score - voltage_penalty
            transmission = contact_fraction
            trial.set_user_attr("detector_contact_score", contact_score)
        elif str(config.get("objective_mode", "")).lower() == "detector_window_quality":
            active_fraction = float(
                metrics_last.get(
                    "detector_active_contact_fraction",
                    metrics_last.get("transmission_geometric", metrics_last.get("transmission", 0.0)),
                )
                or 0.0
            )
            forward_fraction = float(metrics_last.get("detector_active_forward_fraction") or 0.0)
            theta_mean = float(metrics_last.get("detector_contact_angle_theta_mean_deg") or 180.0)
            theta_sigma = float(metrics_last.get("detector_contact_angle_theta_sigma_deg") or 180.0)
            theta_p95 = float(metrics_last.get("detector_contact_angle_theta_p95_deg") or 180.0)
            bpm_center_fraction = (
                float(metrics_last.get("bpm_real_center") or 0.0)
                / float(metrics_last.get("ions_flown") or 1.0)
            )
            window_cfg = dict(config.get("detector_window_quality_weights", {}))
            window_quality_score = (
                float(window_cfg.get("active_contact", 6.0)) * active_fraction
                + float(window_cfg.get("forward", 1.0)) * forward_fraction
                + float(window_cfg.get("bpm_center", 0.2)) * bpm_center_fraction
                - float(window_cfg.get("theta_mean", 0.10)) * theta_mean
                - float(window_cfg.get("theta_sigma", 0.20)) * theta_sigma
                - float(window_cfg.get("theta_p95", 0.03)) * theta_p95
            )
            score = window_quality_score - voltage_penalty
            transmission = active_fraction
            trial.set_user_attr("detector_window_quality_score", window_quality_score)
        elif str(config.get("objective_mode", "")).lower() == "angle_quality":
            contact_fraction = float(metrics_last.get("detector_contact_fraction") or 0.0)
            geometric_fraction = float(
                metrics_last.get("transmission_geometric", metrics_last.get("transmission", 0.0))
                or 0.0
            )
            bpm_center_fraction = (
                float(metrics_last.get("bpm_real_center") or 0.0)
                / float(metrics_last.get("ions_flown") or 1.0)
            )
            theta_mean = float(metrics_last.get("terminal_angle_theta_mean_deg") or 180.0)
            theta_p95 = float(metrics_last.get("terminal_angle_theta_p95_deg") or 180.0)
            theta_p99 = float(metrics_last.get("terminal_angle_theta_p99_deg") or 180.0)
            forward_fraction = (
                float(metrics_last.get("terminal_angle_forward_z") or 0.0)
                / float(metrics_last.get("ions_flown") or 1.0)
            )
            angle_cfg = dict(config.get("angle_quality_weights", {}))
            angle_quality_score = (
                float(angle_cfg.get("contact", 5.0)) * contact_fraction
                + float(angle_cfg.get("geometric", 0.5)) * geometric_fraction
                + float(angle_cfg.get("bpm_center", 0.4)) * bpm_center_fraction
                + float(angle_cfg.get("forward", 0.5)) * forward_fraction
                - float(angle_cfg.get("theta_p95", 0.06)) * theta_p95
                - float(angle_cfg.get("theta_mean", 0.03)) * theta_mean
                - float(angle_cfg.get("theta_p99", 0.01)) * theta_p99
            )
            score = angle_quality_score - voltage_penalty
            transmission = contact_fraction
            trial.set_user_attr("angle_quality_score", angle_quality_score)
        trial.set_user_attr("metrics", metrics_last)
        trial.set_user_attr("repeat_values", values)
        trial.set_user_attr("guidance_values", guidance_values)
        trial.set_user_attr("valid_transmission", transmission)
        trial.set_user_attr("guidance_score", guidance)
        trial.set_user_attr("objective_aux_weight", aux_weight)
        trial.set_user_attr("voltage_l2_cost", voltage_l2_cost)
        trial.set_user_attr("voltage_boundary_cost", voltage_boundary_cost)
        trial.set_user_attr("voltage_penalty", voltage_penalty)
        if front_score is not None:
            trial.set_user_attr("front_guided_score", front_score)
        mode = str(config.get("objective_mode", "")).lower()
        if mode == "detector_window_quality":
            print(
                f"Trial {trial.number}: "
                f"active={100.0 * float(metrics_last.get('detector_active_contact_fraction') or 0.0):6.2f}% "
                f"fwd={100.0 * float(metrics_last.get('detector_active_forward_fraction') or 0.0):6.2f}% "
                f"n={int(metrics_last.get('detector_active_contact_count') or 0):3d}/"
                f"{int(metrics_last.get('ions_flown') or 0):3d} "
                f"theta_mu={float(metrics_last.get('detector_contact_angle_theta_mean_deg') or 0.0):5.2f} "
                f"theta_sig={float(metrics_last.get('detector_contact_angle_theta_sigma_deg') or 0.0):5.2f} "
                f"theta95={float(metrics_last.get('detector_contact_angle_theta_p95_deg') or 0.0):5.2f} "
                f"bpm={float(metrics_last.get('bpm_real_score') or 0.0):.3f} "
                f"vcost={voltage_l2_cost:.3f} bcost={voltage_boundary_cost:.3f} "
                f"obj={score:.6f} | "
                + " ".join(f"{key}={value:.6g}" for key, value in voltages.items())
            )
        else:
            extra = ""
            if "loss_E19_active_window_proximity_mean" in metrics_last:
                extra += (
                    f" e19={float(metrics_last.get('loss_E19_active_window_proximity_mean') or 0.0):.4f}"
                    f" e19n={int(metrics_last.get('loss_E19') or 0)}"
                )
            if "detector_contact_count" in metrics_last:
                extra += (
                    f" contact={int(metrics_last.get('detector_contact_count') or 0)}"
                    f"({100.0 * float(metrics_last.get('detector_contact_fraction') or 0.0):.1f}%)"
                )
            if "terminal_angle_theta_p95_deg" in metrics_last:
                extra += (
                    f" th_mean={float(metrics_last.get('terminal_angle_theta_mean_deg') or 0.0):.2f}"
                    f" th95={float(metrics_last.get('terminal_angle_theta_p95_deg') or 0.0):.2f}"
                    f" th99={float(metrics_last.get('terminal_angle_theta_p99_deg') or 0.0):.2f}"
                )
            if "detector_valid_valid" in metrics_last:
                extra += (
                    f" front={int(metrics_last.get('detector_valid_valid') or 0)}"
                    f"/{int(metrics_last.get('detector_valid_in_window') or 0)}"
                    f" back={int(metrics_last.get('detector_valid_wrong_side') or 0)}"
                    f" theta={float(metrics_last.get('detector_valid_theta_mean_deg') or 0.0):.1f}"
                )
            if "detector_face_x_min" in metrics_last:
                extra += (
                    " faces="
                    f"x-:{int(metrics_last.get('detector_face_x_min') or 0)}"
                    f",x+:{int(metrics_last.get('detector_face_x_max') or 0)}"
                    f",y-:{int(metrics_last.get('detector_face_y_min') or 0)}"
                    f",y+:{int(metrics_last.get('detector_face_y_max') or 0)}"
                    f",z-:{int(metrics_last.get('detector_face_z_min') or 0)}"
                    f",z+:{int(metrics_last.get('detector_face_z_max') or 0)}"
                )
            if "bpm_real_score" in metrics_last:
                extra += (
                    f" bpm={float(metrics_last.get('bpm_real_score') or 0.0):.4f}"
                    f" cross={int(metrics_last.get('bpm_real_crossings') or 0)}"
                    f" center={int(metrics_last.get('bpm_real_center') or 0)}"
                )
            print(
                f"Trial {trial.number}: trans={100 * transmission:.2f}% "
                f"guide={guidance:.4f}{extra} vcost={voltage_l2_cost:.4f}"
                f" bcost={voltage_boundary_cost:.4f} obj={score:.6f} | "
                + " ".join(f"{key}={value:.6g}" for key, value in voltages.items())
            )
        return score

    return objective


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "optuna_config.json")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--one", action="store_true", help="Ejecuta una sola corrida")
    args = parser.parse_args()
    os.chdir(ROOT)
    config = load_config(args.config)

    if str(config.get("sampler", "")).lower() == "botorch":
        sampler = botorch_sampler(config)
        study = optuna.create_study(
            study_name=str(config["study_name"]),
            storage=str(config["storage"]),
            direction="maximize",
            sampler=sampler,
            load_if_exists=True,
        )
        enqueue_startup_trials(study, config)
        if args.status:
            print_status(study)
            return

        objective = build_objective(config)
        patience = int(config["stagnation_trials"])
        improvement = float(config["minimum_improvement"])
        start_after = int(config.get("stagnation_start_after", config.get("startup_trials", 0)))

        def stop_on_stagnation(
            study: optuna.Study, trial: optuna.trial.FrozenTrial
        ) -> None:
            if stagnated(study, patience, improvement, start_after=start_after):
                print(
                    f"Parada: {patience} corridas sin mejora de "
                    f"{100 * improvement:.2f} puntos porcentuales."
                )
                study.stop()

        try:
            print("Fase BoTorch BO activa")
            study.optimize(
                objective,
                n_trials=1 if args.one else None,
                callbacks=[stop_on_stagnation],
            )
        except KeyboardInterrupt:
            print("Interrumpido. Estudio guardado en SQLite.")
        finally:
            print_status(study)
        return

    if str(config.get("sampler", "")).lower() in {"nsga2", "nsgaii"}:
        sampler = nsga2_sampler(config)
        study = optuna.create_study(
            study_name=str(config["study_name"]),
            storage=str(config["storage"]),
            direction="maximize",
            sampler=sampler,
            load_if_exists=True,
        )
        enqueue_startup_trials(study, config)
        if args.status:
            print_status(study)
            return

        objective = build_objective(config)
        patience = int(config["stagnation_trials"])
        improvement = float(config["minimum_improvement"])
        start_after = int(config.get("stagnation_start_after", 0))

        def stop_on_stagnation(
            study: optuna.Study, trial: optuna.trial.FrozenTrial
        ) -> None:
            if stagnated(study, patience, improvement, start_after=start_after):
                print(
                    f"Parada: {patience} corridas sin mejora de "
                    f"{100 * improvement:.2f} puntos porcentuales."
                )
                study.stop()

        try:
            print("Fase NSGA-II activa")
            study.optimize(
                objective,
                n_trials=1 if args.one else None,
                callbacks=[stop_on_stagnation],
            )
        except KeyboardInterrupt:
            print("Interrumpido. Estudio guardado en SQLite.")
        finally:
            print_status(study)
        return

    if str(config.get("sampler", "")).lower() == "cmaes":
        sampler = cmaes_sampler(config)
        study = optuna.create_study(
            study_name=str(config["study_name"]),
            storage=str(config["storage"]),
            direction="maximize",
            sampler=sampler,
            load_if_exists=True,
        )
        enqueue_startup_trials(study, config)
        if args.status:
            print_status(study)
            return

        objective = build_objective(config)
        patience = int(config["stagnation_trials"])
        improvement = float(config["minimum_improvement"])
        start_after = int(config.get("stagnation_start_after", 0))

        def stop_on_stagnation(
            study: optuna.Study, trial: optuna.trial.FrozenTrial
        ) -> None:
            if stagnated(study, patience, improvement, start_after=start_after):
                print(
                    f"Parada: {patience} corridas sin mejora de "
                    f"{100 * improvement:.2f} puntos porcentuales."
                )
                study.stop()

        try:
            print("Fase CMA-ES activa")
            study.optimize(
                objective,
                n_trials=1 if args.one else None,
                callbacks=[stop_on_stagnation],
            )
        except KeyboardInterrupt:
            print("Interrumpido. Estudio guardado en SQLite.")
        finally:
            print_status(study)
        return

    qmc_sampler = optuna.samplers.QMCSampler(
        qmc_type="sobol",
        scramble=True,
        seed=int(config["seed"]),
    )
    study = optuna.create_study(
        study_name=str(config["study_name"]),
        storage=str(config["storage"]),
        direction="maximize",
        sampler=qmc_sampler,
        load_if_exists=True,
    )
    enqueue_startup_trials(study, config)
    if args.status:
        print_status(study)
        return

    objective = build_objective(config)
    patience = int(config["stagnation_trials"])
    improvement = float(config["minimum_improvement"])

    enqueue_local_refinement(study, config)

    def after_trial(study: optuna.Study, trial: optuna.trial.FrozenTrial) -> None:
        enqueue_local_refinement(study, config)
        if stagnated(
            study,
            patience,
            improvement,
            start_after=int(config["startup_trials"]),
        ):
            print(
                f"Parada: {patience} corridas sin mejora de "
                f"{100 * improvement:.2f} puntos porcentuales."
            )
            study.stop()

    try:
        startup_target = int(config["startup_trials"])
        complete_count = len(completed_trials(study))
        if complete_count < startup_target:
            qmc_trials = 1 if args.one else startup_target - complete_count
            print(f"Fase Sobol: {complete_count}/{startup_target} completas")
            study.optimize(objective, n_trials=qmc_trials, callbacks=[after_trial])

        if args.one and complete_count >= startup_target:
            gp_sampler = optuna.samplers.GPSampler(
                seed=int(config["seed"]),
                n_startup_trials=startup_target,
                deterministic_objective=False,
            )
            study = optuna.load_study(
                study_name=str(config["study_name"]),
                storage=str(config["storage"]),
                sampler=gp_sampler,
            )
            print("Fase BO-GP activa")
            enqueue_local_refinement(study, config)
            study.optimize(objective, n_trials=1, callbacks=[after_trial])
        elif not args.one and len(completed_trials(study)) >= startup_target:
            gp_sampler = optuna.samplers.GPSampler(
                seed=int(config["seed"]),
                n_startup_trials=startup_target,
                deterministic_objective=False,
            )
            study = optuna.load_study(
                study_name=str(config["study_name"]),
                storage=str(config["storage"]),
                sampler=gp_sampler,
            )
            print("Fase BO-GP activa")
            enqueue_local_refinement(study, config)
            study.optimize(objective, n_trials=None, callbacks=[after_trial])
    except KeyboardInterrupt:
        print("Interrumpido. Estudio guardado en SQLite.")
    finally:
        print_status(study)


if __name__ == "__main__":
    main()
