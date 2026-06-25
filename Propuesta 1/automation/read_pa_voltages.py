"""Lee voltajes de electrodos codificados en un PA0 usando su PA#."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def header_size(path: Path) -> tuple[int, float, int]:
    with path.open("rb") as handle:
        mode = struct.unpack("<i", handle.read(4))[0]
        _, max_voltage, nx, ny, nz, _ = struct.unpack("<idiiii", handle.read(28))
    size = 56 if mode <= -2 else 32
    return size, max_voltage, nx * ny * nz


def read_voltages(pa_sharp: Path, pa_zero: Path) -> dict[int, float]:
    try:
        import numpy as np
    except ImportError as exc:
        raise RuntimeError("Este diagnóstico requiere NumPy") from exc

    offset, max_voltage, count = header_size(pa_sharp)
    sharp = np.memmap(pa_sharp, dtype="<f8", mode="r", offset=offset, shape=(count,))
    zero = np.memmap(pa_zero, dtype="<f8", mode="r", offset=offset, shape=(count,))
    found: dict[int, float] = {}
    chunk_size = 1_000_000
    for start in range(0, count, chunk_size):
        values = np.asarray(sharp[start : start + chunk_size])
        identifiers = np.rint(values - 2 * max_voltage).astype(np.int32)
        for electrode in range(1, 42):
            if electrode in found:
                continue
            matches = np.flatnonzero(identifiers == electrode)
            if matches.size:
                index = start + int(matches[0])
                found[electrode] = float(zero[index] - 2 * max_voltage)
        if len(found) == 41:
            break
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pa_sharp", type=Path)
    parser.add_argument("pa_zero", type=Path)
    args = parser.parse_args()
    for electrode, voltage in sorted(read_voltages(args.pa_sharp, args.pa_zero).items()):
        print(f"V{electrode}={voltage:g}")


if __name__ == "__main__":
    main()
