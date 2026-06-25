"""Inventaría electrodos STL exportados y sus límites en coordenadas SIMION."""

from __future__ import annotations

import argparse
import json
import re
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ELECTRODE_PATTERN = re.compile(r"S_(\d+)\.stl$", re.IGNORECASE)

# Transformación usada al importar el CAD en S_.PA#.
# Verificada contra los límites PA: X=0..995, Y=0..153, Z=0..638.
SIMION_OFFSET_Y_MM = 75.0
SIMION_OFFSET_Z_MM = 380.0


def read_binary_stl_bounds(path: Path) -> tuple[float, float, float, float, float, float, int]:
    data = path.read_bytes()
    if len(data) < 84:
        raise ValueError(f"STL incompleto: {path}")
    triangle_count = struct.unpack_from("<I", data, 80)[0]
    expected_size = 84 + 50 * triangle_count
    if len(data) != expected_size:
        raise ValueError(
            f"STL no es binario o tiene tamaño inesperado: {path} "
            f"({len(data)} != {expected_size})"
        )

    xmin = ymin = zmin = float("inf")
    xmax = ymax = zmax = float("-inf")
    for triangle in range(triangle_count):
        vertices = struct.unpack_from("<9f", data, 84 + triangle * 50 + 12)
        xs, ys, zs = vertices[0::3], vertices[1::3], vertices[2::3]
        xmin, xmax = min(xmin, *xs), max(xmax, *xs)
        ymin, ymax = min(ymin, *ys), max(ymax, *ys)
        zmin, zmax = min(zmin, *zs), max(zmax, *zs)
    return xmin, xmax, ymin, ymax, zmin, zmax, triangle_count


def to_simion_bounds(
    cad_bounds: tuple[float, float, float, float, float, float, int]
) -> dict[str, float | int]:
    xmin, xmax, ymin, ymax, zmin, zmax, triangles = cad_bounds
    return {
        "x_min_mm": -xmax,
        "x_max_mm": -xmin,
        "y_min_mm": ymin + SIMION_OFFSET_Y_MM,
        "y_max_mm": ymax + SIMION_OFFSET_Y_MM,
        "z_min_mm": zmin + SIMION_OFFSET_Z_MM,
        "z_max_mm": zmax + SIMION_OFFSET_Z_MM,
        "triangles": triangles,
    }


def parse_electrode_selection(text: str) -> set[int]:
    selected: set[int] = set()
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        if "-" in item:
            start_text, end_text = item.split("-", 1)
            start, end = int(start_text), int(end_text)
            if end < start:
                raise ValueError(f"Rango invertido: {item}")
            selected.update(range(start, end + 1))
        else:
            selected.add(int(item))
    return selected


def inventory(
    directory: Path,
    x_threshold_mm: float,
    electrode_numbers: set[int] | None = None,
) -> dict[str, object]:
    electrodes: list[dict[str, object]] = []
    for path in directory.glob("S_*.stl"):
        match = ELECTRODE_PATTERN.fullmatch(path.name)
        if not match:
            continue
        bounds = to_simion_bounds(read_binary_stl_bounds(path))
        relation = "left"
        if float(bounds["x_min_mm"]) > x_threshold_mm:
            relation = "entirely_right"
        elif float(bounds["x_max_mm"]) > x_threshold_mm:
            relation = "intersects_right"
        electrodes.append(
            {
                "electrode": int(match.group(1)),
                "file": path.name,
                "relation_to_threshold": relation,
                **bounds,
            }
        )

    electrodes.sort(key=lambda item: int(item["electrode"]))
    if electrode_numbers is None:
        selected = [
            item for item in electrodes if item["relation_to_threshold"] != "left"
        ]
        selection_rule = (
            f"electrode geometry has any point with X > {x_threshold_mm:g} mm"
        )
    else:
        selected = [
            item for item in electrodes if int(item["electrode"]) in electrode_numbers
        ]
        selection_rule = "explicit electrode identifiers"
    return {
        "coordinate_system": "SIMION workbench millimetres",
        "selection_rule": selection_rule,
        "x_threshold_mm": x_threshold_mm if electrode_numbers is None else None,
        "selected_electrodes": [item["electrode"] for item in selected],
        "electrodes": selected,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=ROOT / "exportado")
    parser.add_argument("--x-threshold", type=float, default=740.0)
    parser.add_argument(
        "--electrodes",
        help="Selección explícita, por ejemplo: 1-22 o 1,2,8,14",
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    selected = parse_electrode_selection(args.electrodes) if args.electrodes else None
    result = inventory(args.directory, args.x_threshold, selected)
    text = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
