"""Ejecuta una prueba SIMION efímera desde la raíz del proyecto."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from automation.simion_automation import main


ROOT = Path(__file__).resolve().parent


if __name__ == "__main__":
    os.chdir(ROOT)
    extra_arguments = sys.argv[1:]
    sys.argv = [
        sys.argv[0],
        "run",
        "--iob",
        "exportado/experimento.iob",
        "--report",
        "automation/runtime/transmision.csv",
        "--recording",
        "exportado/deteccion_x455.rec",
        "--particles",
        "exportado/pruebaSimple41.fly2",
        "--replace-report",
        *extra_arguments,
    ]
    try:
        main()
    except (FileNotFoundError, RuntimeError, TimeoutError, ValueError) as exc:
        raise SystemExit(f"ERROR: {exc}") from exc
