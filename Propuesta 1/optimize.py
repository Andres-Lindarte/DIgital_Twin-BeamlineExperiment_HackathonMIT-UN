"""Optimizacion BO-GP de electrodos 1..4 mediante Optuna GPSampler."""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import random
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


def load_config(path: Path) -> dict[str, object]:
    config = json.loads(path.read_text(encoding="utf-8"))
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
        transmission = (
            float(metrics.get("transmission", best.value))
            if isinstance(metrics, dict)
            else float(best.value)
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


def build_objective(config: dict[str, object]):
    repeats = int(config["repeats_per_trial"])
    aux_weight = float(config.get("objective_aux_weight", 0.005))
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

    def objective(trial: optuna.Trial) -> float:
        voltages = dict(fixed)
        voltages.update({
            f"V{electrode}": trial.suggest_float(
                f"V{electrode}", *bounds[f"V{electrode}"]
            )
            for electrode in optimized
        })
        for electrode in range(1, 23):
            voltages.setdefault(f"V{electrode}", 0.0)
        voltages = dict(sorted(voltages.items()))
        trial.set_user_attr("voltages", voltages)
        values: list[float] = []
        guidance_values: list[float] = []
        metrics_last: dict[str, object] = {}
        for repeat in range(repeats):
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
            guidance_values.append(guidance_score(metrics))
            metrics_last = metrics
            trial.set_user_attr("elapsed_seconds", metadata["elapsed_seconds"])

        transmission = sum(values) / len(values)
        guidance = sum(guidance_values) / len(guidance_values)
        score = transmission + aux_weight * guidance
        trial.set_user_attr("metrics", metrics_last)
        trial.set_user_attr("repeat_values", values)
        trial.set_user_attr("guidance_values", guidance_values)
        trial.set_user_attr("valid_transmission", transmission)
        trial.set_user_attr("guidance_score", guidance)
        trial.set_user_attr("objective_aux_weight", aux_weight)
        print(
            f"Trial {trial.number}: trans={100 * transmission:.2f}% "
            f"guide={guidance:.4f} obj={score:.6f} | "
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
