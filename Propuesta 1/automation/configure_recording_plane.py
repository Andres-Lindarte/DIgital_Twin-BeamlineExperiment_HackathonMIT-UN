"""Crea una copia .rec con un único plano de cruce X, Y o Z activo."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


FLAG_OFFSETS = {"X": 76, "Y": 78, "Z": 80}
VALUE_OFFSETS = {"X": 82, "Y": 90, "Z": 98}


def configure(source: Path, output: Path, axis: str, value: float) -> None:
    axis = axis.upper()
    if axis not in FLAG_OFFSETS:
        raise ValueError("axis debe ser X, Y o Z")
    data = bytearray(source.read_bytes())
    if len(data) < 106:
        raise ValueError(f"Formato .rec inesperado: {len(data)} bytes")
    for candidate, offset in FLAG_OFFSETS.items():
        struct.pack_into("<H", data, offset, 1 if candidate == axis else 0)
    struct.pack_into("<d", data, VALUE_OFFSETS[axis], float(value))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("axis", choices=["X", "Y", "Z", "x", "y", "z"])
    parser.add_argument("value", type=float)
    args = parser.parse_args()
    configure(args.source, args.output, args.axis, args.value)
    print(f"Creado {args.output}: plano {args.axis.upper()}={args.value:g} mm")


if __name__ == "__main__":
    main()
