"""Extract SIMION detector reports and safely prepare 41 electrode voltages.

No third-party dependencies.  The optimizer can call this module without
depending on SIMION's GUI or on a specific optimization library.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import math
import re
import statistics
import subprocess
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable


NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"


@dataclass(frozen=True)
class IonEvent:
    ion: int
    event: str
    tof_us: float | None = None
    mass_amu: float | None = None
    charge_e: float | None = None
    x_mm: float | None = None
    y_mm: float | None = None
    z_mm: float | None = None
    speed_mm_us: float | None = None
    azimuth_deg: float | None = None
    elevation_deg: float | None = None
    kinetic_energy_ev: float | None = None


@dataclass(frozen=True)
class SimulationRun:
    ions_flown: int
    events: tuple[IonEvent, ...]
    source: str


def parse_adjustables(items: Iterable[str] | None) -> dict[str, float]:
    result: dict[str, float] = {}
    for item in items or []:
        if "=" not in item:
            raise ValueError(f"Adjustable debe tener forma NOMBRE=VALOR: {item}")
        name, value_text = item.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise ValueError(f"Nombre adjustable inválido: {name}")
        value = float(value_text)
        if not math.isfinite(value):
            raise ValueError(f"Valor adjustable no finito: {item}")
        result[name] = value
    return result


def _last_run_text(text: str) -> str:
    starts = list(re.finditer(r"(?im)^\s*\"?Begin Fly'm\b", text))
    return text[starts[-1].start() :] if starts else text


def _field(block: str, name: str, unit: str) -> float | None:
    match = re.search(rf"\b{re.escape(name)}\(({NUMBER})\s+{re.escape(unit)}\)", block)
    return float(match.group(1)) if match else None


def _parse_verbose(run_text: str) -> list[IonEvent]:
    starts = list(re.finditer(r"\bIon\((\d+)\)\s+Event\((.*?)\)", run_text, re.S))
    events: list[IonEvent] = []
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(run_text)
        block = run_text[match.start() : end]
        events.append(
            IonEvent(
                ion=int(match.group(1)),
                event=" ".join(match.group(2).split()),
                tof_us=_field(block, "TOF", "usec"),
                mass_amu=_field(block, "Mass", "amu"),
                charge_e=_field(block, "Charge", "e"),
                x_mm=_field(block, "X", "mm"),
                y_mm=_field(block, "Y", "mm"),
                z_mm=_field(block, "Z", "mm"),
                speed_mm_us=_field(block, "Vt", "mm/usec"),
                azimuth_deg=_field(block, "Azm", "deg"),
                elevation_deg=_field(block, "Elv", "deg"),
                kinetic_energy_ev=_field(block, "KE", "eV"),
            )
        )
    return events


def _parse_tabular(run_text: str, event_code: int | None) -> list[IonEvent]:
    """Parse SIMION's numeric CSV recording format.

    Event codes are workbench-specific.  If ``event_code`` is omitted, all
    numeric rows are returned; callers should not interpret them as detector
    hits unless the recording contains only detector events.
    """
    lines = run_text.replace("\f", "").splitlines()
    header_index = next(
        (i for i, line in enumerate(lines) if "Ion N" in line and "Events" in line),
        None,
    )
    if header_index is None:
        return []

    events: list[IonEvent] = []
    for row in csv.reader(lines[header_index + 1 :]):
        if len(row) < 12:
            continue
        try:
            ion = int(float(row[0]))
            code = int(float(row[1]))
            values = [float(value) for value in row[2:12]]
        except ValueError:
            continue
        if event_code is not None and code != event_code:
            continue
        events.append(
            IonEvent(
                ion=ion,
                event=f"event_code={code}",
                tof_us=values[0],
                mass_amu=values[1],
                charge_e=values[2],
                x_mm=values[3],
                y_mm=values[4],
                z_mm=values[5],
                speed_mm_us=values[6],
                azimuth_deg=values[7],
                elevation_deg=values[8],
                kinetic_energy_ev=None,
            )
        )
    return events


def parse_report(path: str | Path, event_code: int | None = None) -> SimulationRun:
    path = Path(path)
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    run_text = _last_run_text(text)
    flown_match = re.search(r"Number of Ions to Fly\s*=\s*(\d+)", run_text)
    if not flown_match:
        raise ValueError(f"No se encontró 'Number of Ions to Fly' en {path}")
    events = _parse_verbose(run_text) or _parse_tabular(run_text, event_code)
    return SimulationRun(int(flown_match.group(1)), tuple(events), str(path.resolve()))


def _mean(values: Iterable[float | None]) -> float | None:
    clean = [value for value in values if value is not None]
    return statistics.fmean(clean) if clean else None


def _stdev(values: Iterable[float | None]) -> float | None:
    clean = [value for value in values if value is not None]
    return statistics.stdev(clean) if len(clean) >= 2 else (0.0 if clean else None)


def _percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, math.ceil(fraction * len(ordered)) - 1))
    return ordered[index]


def calculate_metrics(
    run: SimulationRun,
    target_x_mm: float | None = None,
    target_y_mm: float | None = None,
    aperture_radius_mm: float | None = None,
) -> dict[str, Any]:
    # One ion may cross the detector plane more than once. Keep first hit.
    first_hits: dict[int, IonEvent] = {}
    for event in run.events:
        first_hits.setdefault(event.ion, event)
    hits = list(first_hits.values())
    detected = len(hits)
    transmission = detected / run.ions_flown

    plane_matches = [
        re.search(r"Crossed\s+([XYZ])\s*=\s*(%s)\s+Plane" % NUMBER, hit.event)
        for hit in hits
    ]
    plane_matches = [match for match in plane_matches if match]
    plane_axis = (
        plane_matches[0].group(1)
        if plane_matches and len({match.group(1) for match in plane_matches}) == 1
        else None
    )
    plane_value = float(plane_matches[0].group(2)) if plane_axis else None
    transverse = {
        "X": ("Y", "Z"),
        "Y": ("X", "Z"),
        "Z": ("X", "Y"),
    }.get(plane_axis, ("X", "Y"))

    def coordinate(hit: IonEvent, axis: str) -> float | None:
        return getattr(hit, f"{axis.lower()}_mm")

    axis_u, axis_v = transverse
    positioned = [
        hit
        for hit in hits
        if coordinate(hit, axis_u) is not None and coordinate(hit, axis_v) is not None
    ]
    centroid_u = _mean(coordinate(hit, axis_u) for hit in positioned)
    centroid_v = _mean(coordinate(hit, axis_v) for hit in positioned)
    radii_centroid: list[float] = []
    if centroid_u is not None and centroid_v is not None:
        radii_centroid = [
            math.hypot(
                coordinate(hit, axis_u) - centroid_u,  # type: ignore[operator]
                coordinate(hit, axis_v) - centroid_v,  # type: ignore[operator]
            )
            for hit in positioned
        ]

    metrics: dict[str, Any] = {
        "ions_flown": run.ions_flown,
        "ions_detected": detected,
        "transmission": transmission,
        "transmission_percent": 100.0 * transmission,
        "detector_plane_axis": plane_axis,
        "detector_plane_value_mm": plane_value,
        "transverse_axes": [axis_u, axis_v],
        f"centroid_{axis_u.lower()}_mm": centroid_u,
        f"centroid_{axis_v.lower()}_mm": centroid_v,
        f"sigma_{axis_u.lower()}_mm": _stdev(
            coordinate(hit, axis_u) for hit in positioned
        ),
        f"sigma_{axis_v.lower()}_mm": _stdev(
            coordinate(hit, axis_v) for hit in positioned
        ),
        "rms_radius_about_centroid_mm": (
            math.sqrt(statistics.fmean(radius * radius for radius in radii_centroid))
            if radii_centroid
            else None
        ),
        "radius95_about_centroid_mm": _percentile(radii_centroid, 0.95),
        "mean_tof_us": _mean(hit.tof_us for hit in hits),
        "stdev_tof_us": _stdev(hit.tof_us for hit in hits),
        "mean_kinetic_energy_ev": _mean(hit.kinetic_energy_ev for hit in hits),
        "stdev_kinetic_energy_ev": _stdev(hit.kinetic_energy_ev for hit in hits),
    }

    if target_x_mm is not None and target_y_mm is not None:
        radii_target = [
            math.hypot(
                coordinate(hit, axis_u) - target_x_mm,  # type: ignore[operator]
                coordinate(hit, axis_v) - target_y_mm,  # type: ignore[operator]
            )
            for hit in positioned
        ]
        metrics["rms_radius_about_target_mm"] = (
            math.sqrt(statistics.fmean(radius * radius for radius in radii_target))
            if radii_target
            else None
        )
        if aperture_radius_mm is not None:
            in_aperture = sum(radius <= aperture_radius_mm for radius in radii_target)
            metrics["ions_in_aperture"] = in_aperture
            metrics["aperture_transmission"] = in_aperture / run.ions_flown

    return metrics


def parse_detector_summary(stdout: str) -> dict[str, Any] | None:
    """Extrae resumen emitido por el detector virtual del programa Lua."""
    lines = [line.strip() for line in stdout.splitlines() if "DETECT_SUMMARY" in line]
    if not lines:
        return None
    values = {
        key: float(value)
        for key, value in re.findall(rf"([A-Za-z][A-Za-z0-9_]*)=({NUMBER})", lines[-1])
    }
    required = {"launched", "crossings_from_right", "valid", "transmission"}
    missing = required - values.keys()
    if missing:
        raise ValueError(
            "DETECT_SUMMARY incompleto; faltan: " + ", ".join(sorted(missing))
        )

    integer_fields = {
        "launched",
        "crossings_from_right",
        "in_aperture",
        "valid",
        "theta_le_max",
        "theta_le_scaled",
        "theta_le_1",
        "theta_le_2",
        "theta_le_5",
        "theta_le_10",
        "theta_le_15",
        "radius_le_1",
        "radius_le_2",
        "radius_le_3",
        "radius_le_4",
    }
    parsed: dict[str, Any] = {
        key: int(value) if key in integer_fields else value
        for key, value in values.items()
    }
    transmission = float(parsed["transmission"])
    return {
        "ions_flown": parsed["launched"],
        "ions_detected": parsed["valid"],
        "transmission": transmission,
        "transmission_percent": 100.0 * transmission,
        "ions_crossing_from_right": parsed["crossings_from_right"],
        "ions_in_aperture": parsed.get("in_aperture", 0),
        "ions_radius_le_detector": parsed.get("radius_le_1", 0),
        "ions_radius_le_guidance_2": parsed.get("radius_le_2", 0),
        "ions_radius_le_guidance_3": parsed.get("radius_le_3", 0),
        "ions_radius_le_guidance_4": parsed.get("radius_le_4", 0),
        "detector_plane_axis": "X",
        "detector_plane_value_mm": parsed.get("x_mm"),
        "detector_center_y_mm": parsed.get("y_mm"),
        "detector_center_z_mm": parsed.get("z_mm"),
        "detector_radius_mm": parsed.get("radius_mm"),
        "detector_guidance_radius_2_mm": parsed.get("guidance_radius_2_mm"),
        "detector_guidance_radius_3_mm": parsed.get("guidance_radius_3_mm"),
        "detector_guidance_radius_4_mm": parsed.get("guidance_radius_4_mm"),
        "detector_direction": "reference_exit_to_detector",
        "detector_direction_unit": [-0.9999996669757351, 0.0, -0.0008161178953624273],
        "theta_max_deg": parsed.get("theta_max_deg"),
        "mean_theta_deg": parsed.get("mean_theta_deg"),
        "ions_theta_le_max_deg": parsed.get("theta_le_max", 0),
        "ions_theta_le_scaled_deg": parsed.get("theta_le_scaled", 0),
        "ions_theta_le_1_deg": parsed.get("theta_le_1", 0),
        "ions_theta_le_2_deg": parsed.get("theta_le_2", 0),
        "ions_theta_le_5_deg": parsed.get("theta_le_5", 0),
        "ions_theta_le_10_deg": parsed.get("theta_le_10", 0),
        "ions_theta_le_15_deg": parsed.get("theta_le_15", 0),
    }


def load_voltage_config(path: str | Path) -> dict[str, Any]:
    config = json.loads(Path(path).read_text(encoding="utf-8"))
    current = config.get("current_voltages")
    bounds = config.get("bounds")
    if not isinstance(current, list) or len(current) != 41:
        raise ValueError("current_voltages debe contener exactamente 41 valores")
    if not isinstance(bounds, list) or len(bounds) != 41:
        raise ValueError("bounds debe contener exactamente 41 pares [mínimo, máximo]")
    return config


def validate_candidate(candidate: list[float], config: dict[str, Any]) -> list[float]:
    if len(candidate) != 41:
        raise ValueError("Candidato debe contener exactamente 41 voltajes")
    current = [float(value) for value in config["current_voltages"]]
    bounds = config["bounds"]
    max_step_raw = config.get("max_step", math.inf)
    max_steps = (
        [float(max_step_raw)] * 41
        if isinstance(max_step_raw, (int, float))
        else [float(value) for value in max_step_raw]
    )
    if len(max_steps) != 41:
        raise ValueError("max_step debe ser número o lista de 41 valores")

    checked: list[float] = []
    for index, raw in enumerate(candidate):
        voltage = float(raw)
        if not math.isfinite(voltage):
            raise ValueError(f"Electrodo {index + 1}: voltaje no finito")
        low, high = map(float, bounds[index])
        if low > high or not low <= voltage <= high:
            raise ValueError(
                f"Electrodo {index + 1}: {voltage} V fuera de [{low}, {high}] V"
            )
        if abs(voltage - current[index]) > max_steps[index]:
            raise ValueError(
                f"Electrodo {index + 1}: cambio {voltage-current[index]:g} V "
                f"supera máximo {max_steps[index]:g} V"
            )
        checked.append(voltage)

    fixed = config.get("fixed_electrodes", {})
    for key, expected in fixed.items():
        index = int(key) - 1
        if not math.isclose(checked[index], float(expected), rel_tol=0.0, abs_tol=1e-12):
            raise ValueError(f"Electrodo {index + 1} debe permanecer en {expected} V")

    adjacent_limit = config.get("max_adjacent_delta")
    if adjacent_limit is not None:
        for index in range(40):
            if abs(checked[index + 1] - checked[index]) > float(adjacent_limit):
                raise ValueError(
                    f"Electrodos {index + 1}-{index + 2}: diferencia supera "
                    f"{adjacent_limit} V"
                )
    return checked


def prepare_voltages(config_path: str | Path, candidate_path: str | Path, output: str | Path) -> None:
    config = load_voltage_config(config_path)
    raw = json.loads(Path(candidate_path).read_text(encoding="utf-8"))
    candidate = raw["voltages"] if isinstance(raw, dict) else raw
    checked = validate_candidate(candidate, config)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["electrode", "voltage"])
        writer.writerows((index, voltage) for index, voltage in enumerate(checked, 1))


def run_simulation(
    simion_exe: str | Path,
    iob_path: str | Path,
    report_path: str | Path,
    timeout_seconds: float = 600,
    event_code: int | None = None,
    recording_path: str | Path | None = None,
    particles_path: str | Path | None = None,
    adjustables: dict[str, float] | None = None,
) -> tuple[SimulationRun, dict[str, Any], dict[str, Any]]:
    """Run one SIMION workbench in batch mode and parse its fresh report."""
    simion_exe = Path(simion_exe).resolve()
    iob_path = Path(iob_path).resolve()
    report_path = Path(report_path).resolve()
    if not simion_exe.is_file():
        raise FileNotFoundError(f"No existe ejecutable SIMION: {simion_exe}")
    if not iob_path.is_file():
        raise FileNotFoundError(f"No existe banco de trabajo .iob: {iob_path}")
    recording = Path(recording_path).resolve() if recording_path else None
    particles = Path(particles_path).resolve() if particles_path else None
    if recording is not None and not recording.is_file():
        raise FileNotFoundError(f"No existe configuración Data Recording: {recording}")
    if particles is not None and not particles.is_file():
        raise FileNotFoundError(f"No existe archivo de partículas: {particles}")
    report_path.parent.mkdir(parents=True, exist_ok=True)

    previous_signature = None
    if report_path.exists():
        stat = report_path.stat()
        previous_signature = (stat.st_mtime_ns, stat.st_size)

    command = [str(simion_exe), "--nogui", "fly"]
    if recording is not None:
        command.extend(
            [
                "--recording",
                str(recording),
                "--recording-enable",
                "1",
                "--recording-output",
                str(report_path),
            ]
        )
    if particles is not None:
        command.extend(["--particles", str(particles)])
    command.extend(["--programs", "1"])
    for name, value in (adjustables or {}).items():
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise ValueError(f"Nombre adjustable inválido: {name}")
        if not math.isfinite(float(value)):
            raise ValueError(f"Valor adjustable no finito: {name}={value}")
        command.extend(["--adjustable", f"{name}={float(value):.17g}"])
    command.extend(["--retain-trajectories", "0", str(iob_path)])
    started = time.monotonic()
    process = subprocess.Popen(
        command,
        cwd=iob_path.parent,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        process.kill()
        process.communicate()
        raise TimeoutError(f"SIMION superó timeout de {timeout_seconds:g} s") from exc
    except KeyboardInterrupt:
        process.kill()
        process.communicate()
        raise
    completed = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    elapsed = time.monotonic() - started

    if completed.returncode != 0:
        decisive = (completed.stderr or completed.stdout).strip().splitlines()[-10:]
        raise RuntimeError(
            f"SIMION terminó con código {completed.returncode}:\n" + "\n".join(decisive)
        )
    if not report_path.is_file():
        raise RuntimeError(f"SIMION terminó sin crear reporte esperado: {report_path}")
    stat = report_path.stat()
    new_signature = (stat.st_mtime_ns, stat.st_size)
    if previous_signature == new_signature:
        raise RuntimeError(
            "SIMION terminó pero reporte no cambió. Revise Data Recording y ruta de salida."
        )

    run = parse_report(report_path, event_code)
    metrics = calculate_metrics(run)
    detector_metrics = parse_detector_summary(completed.stdout)
    if detector_metrics is not None:
        metrics.update(detector_metrics)
    metadata = {
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "elapsed_seconds": elapsed,
        "simion_exe": str(simion_exe),
        "iob": str(iob_path),
        "report": str(report_path),
        "command": command,
        "returncode": completed.returncode,
        "adjustables": adjustables or {},
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }
    return run, metrics, metadata


def save_run_artifacts(
    run: SimulationRun,
    metrics: dict[str, Any],
    metadata: dict[str, Any],
    output_path: str | Path | None = None,
    history_path: str | Path | None = None,
) -> None:
    artifact = {
        "metadata": {key: value for key, value in metadata.items() if key not in {"stdout", "stderr"}},
        "metrics": metrics,
        "events": [asdict(event) for event in run.events],
    }
    resolved_output: Path | None = None
    if output_path is not None:
        resolved_output = Path(output_path)
        resolved_output.parent.mkdir(parents=True, exist_ok=True)
        resolved_output.write_text(
            json.dumps(artifact, indent=2, ensure_ascii=False, allow_nan=False),
            encoding="utf-8",
        )
        log_path = resolved_output.with_suffix(".simion.log")
        log_path.write_text(
            metadata.get("stdout", "") + metadata.get("stderr", ""),
            encoding="utf-8",
        )
    if history_path is not None:
        history_path = Path(history_path)
        history_path.parent.mkdir(parents=True, exist_ok=True)
        summary = {
            **artifact["metadata"],
            **metrics,
            "artifact": str(resolved_output.resolve()) if resolved_output else None,
        }
        with history_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(summary, ensure_ascii=False, allow_nan=False) + "\n")


def _json_dump(value: Any) -> None:
    print(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    analyze = commands.add_parser("analyze", help="Extrae métricas del último Fly'm")
    analyze.add_argument("report", type=Path)
    analyze.add_argument("--event-code", type=int)
    analyze.add_argument("--target-x", type=float)
    analyze.add_argument("--target-y", type=float)
    analyze.add_argument("--aperture-radius", type=float)
    analyze.add_argument("--events-json", type=Path)
    analyze.add_argument("--output", type=Path, help="Guarda métricas como JSON")

    prepare = commands.add_parser("prepare-voltages", help="Valida y escribe 41 voltajes")
    prepare.add_argument("config", type=Path)
    prepare.add_argument("candidate", type=Path)
    prepare.add_argument("--output", type=Path, default=Path("automation/voltages.csv"))

    run = commands.add_parser("run", help="Ejecuta SIMION y analiza reporte fresco")
    run.add_argument("--iob", type=Path, required=True)
    run.add_argument("--report", type=Path, required=True)
    run.add_argument("--simion-exe", type=Path, default=Path("SIMION/simion.exe"))
    run.add_argument("--timeout", type=float, default=600)
    run.add_argument("--event-code", type=int)
    run.add_argument("--recording", type=Path, help="Configuración Data Recording .rec")
    run.add_argument("--particles", type=Path, help="Partículas .fly/.fly2/.ion")
    run.add_argument(
        "--adjustable",
        action="append",
        metavar="NOMBRE=VALOR",
        help="Puede repetirse para pasar adjustables al programa Lua",
    )
    run.add_argument("--output", type=Path, help="Opcional: conserva resultado JSON y log")
    run.add_argument("--history", type=Path, help="Opcional: añade resumen JSONL")
    run.add_argument("--keep-report", action="store_true", help="No borra reporte temporal")
    run.add_argument(
        "--replace-report",
        action="store_true",
        help="Borra reporte temporal previo antes de ejecutar",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.command == "analyze":
        if (args.target_x is None) != (args.target_y is None):
            raise SystemExit("--target-x y --target-y deben usarse juntos")
        run = parse_report(args.report, args.event_code)
        metrics = calculate_metrics(
            run, args.target_x, args.target_y, args.aperture_radius
        )
        if args.events_json:
            args.events_json.parent.mkdir(parents=True, exist_ok=True)
            args.events_json.write_text(
                json.dumps([asdict(event) for event in run.events], indent=2),
                encoding="utf-8",
            )
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(
                json.dumps(metrics, indent=2, ensure_ascii=False, allow_nan=False),
                encoding="utf-8",
            )
        _json_dump(metrics)
    elif args.command == "prepare-voltages":
        prepare_voltages(args.config, args.candidate, args.output)
        _json_dump({"status": "ok", "output": str(args.output), "electrodes": 41})
    elif args.command == "run":
        report_path = args.report.resolve()
        if report_path.exists():
            if args.replace_report:
                report_path.unlink()
            else:
                raise RuntimeError(
                    f"Reporte temporal ya existe: {report_path}. "
                    "Use otra ruta o --replace-report."
                )
        run, metrics, metadata = run_simulation(
            args.simion_exe,
            args.iob,
            report_path,
            args.timeout,
            args.event_code,
            args.recording,
            args.particles,
            parse_adjustables(args.adjustable),
        )
        save_run_artifacts(run, metrics, metadata, args.output, args.history)
        if not args.keep_report:
            report_path.unlink(missing_ok=True)
        _json_dump(
            {
                "status": "ok",
                "elapsed_seconds": metadata["elapsed_seconds"],
                "report_discarded": not args.keep_report,
                "output": str(args.output) if args.output else None,
                "history": str(args.history) if args.history else None,
                "metrics": metrics,
            }
        )


if __name__ == "__main__":
    try:
        main()
    except (FileNotFoundError, RuntimeError, TimeoutError, ValueError) as exc:
        raise SystemExit(f"ERROR: {exc}") from exc
