from __future__ import annotations

import math
from typing import Mapping


DEFAULT_SPEED0 = 130.62


def vz_from_angle_normal(
    theta_mean_deg: float,
    theta_sigma_deg: float,
    speed: float = DEFAULT_SPEED0,
) -> dict[str, float]:
    """Deriva estadisticas de vz asumiendo theta ~ Normal(mu, sigma).

    La media incluye el factor exp(-sigma^2/2). La sigma usa Var(cos theta)
    analitica para una normal.
    """

    theta = math.radians(float(theta_mean_deg))
    sigma = max(0.0, math.radians(float(theta_sigma_deg)))
    speed = float(speed)
    cos_mean = math.cos(theta) * math.exp(-0.5 * sigma * sigma)
    cos2_mean = 0.5 * (1.0 + math.cos(2.0 * theta) * math.exp(-2.0 * sigma * sigma))
    vz_var = max(0.0, cos2_mean - cos_mean * cos_mean)
    return {
        "derived_vz_mean": speed * cos_mean,
        "derived_vz_sigma_physics": speed * math.sqrt(vz_var),
    }


def finite_float(value: object) -> float | None:
    try:
        out = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None
    return out if math.isfinite(out) else None


def residual_from_row(row: Mapping[str, object], speed0: float = DEFAULT_SPEED0) -> float | None:
    """Calcula vz_sigma_real - vz_sigma_physics si la fila tiene datos reales."""

    theta_mean = finite_float(row.get("detector_contact_angle_theta_mean_deg"))
    theta_sigma = finite_float(row.get("detector_contact_angle_theta_sigma_deg"))
    vz_sigma = finite_float(row.get("detector_contact_speed_vz_sigma"))
    if theta_mean is None or theta_sigma is None or vz_sigma is None:
        return None
    speed = finite_float(row.get("detector_contact_speed_speed_mean")) or speed0
    physics = vz_from_angle_normal(theta_mean, theta_sigma, speed)["derived_vz_sigma_physics"]
    return vz_sigma - physics


def add_predicted_derived_metrics(row: dict[str, float], speed0: float = DEFAULT_SPEED0) -> None:
    """Agrega metricas derivadas a una fila de prediccion si existen theta_mu/sigma."""

    theta_mean = finite_float(row.get("pred_detector_contact_angle_theta_mean_deg"))
    theta_sigma = finite_float(row.get("pred_detector_contact_angle_theta_sigma_deg"))
    if theta_mean is None or theta_sigma is None:
        return
    derived = vz_from_angle_normal(theta_mean, theta_sigma, speed0)
    row.update(derived)
    residual = finite_float(row.get("pred_derived_vz_sigma_residual"))
    if residual is not None:
        row["derived_vz_sigma_corrected"] = derived["derived_vz_sigma_physics"] + residual
    else:
        row["derived_vz_sigma_corrected"] = derived["derived_vz_sigma_physics"]
