# Digital Twin baseline

Primera capa del DT: dataset SIMION + ensemble MLP multitarea diferenciable.

Registro de decisiones/resultados vigentes:

```text
dt/EXPERIMENT_LOG.md
```

Use ese archivo para identificar la última solución validada y el siguiente ciclo recomendado.

## 1. Generar candidatos sin correr SIMION

```powershell
.\.venv\Scripts\python.exe .\dt\generate_dataset.py --n 20 --dry-run
```

## 2. Generar dataset real

```powershell
.\.venv\Scripts\python.exe .\dt\generate_dataset.py --n 50
```

Guarda por defecto en:

```text
dt/data/dt_detector_window_dataset.csv
```

Ese dataset nuevo usa la definición física corregida:

- transmisión/contacto = impacto en la ventana activa del detector;
- ángulos = solo impactos forward dentro de esa ventana.

El muestreo está centrado en la franja viable descubierta:

- elites exactas;
- perturbaciones gaussianas de distintos radios;
- barridos por eje;
- interpolaciones/extrapolaciones entre elites;
- una pequeña fracción global LHS configurable.

## 3. Entrenar el ensemble

```powershell
.\.venv\Scripts\python.exe .\dt\train_dt.py
```

Modelos y resumen:

```text
dt/models/baseline_mlp/
```

## 4. Predecir con el DT

```powershell
.\.venv\Scripts\python.exe .\dt\predict_dt.py --voltages V3=-900 V6=-1000 V9=945.045 V10=-9.45424 V11=-73.8701 V12=-760 V15=-165.252 V18=-206.276
```

La salida incluye media del ensemble e incertidumbre por desacuerdo.

## 5. Selección activa de nuevos puntos

```powershell
.\.venv\Scripts\python.exe .\dt\active_select.py --pool 5000 --select 100
```

Para correr SIMION directamente en los puntos seleccionados:

```powershell
.\.venv\Scripts\python.exe .\dt\active_select.py --pool 5000 --select 100 --run-simion
```

## 6. Bucle automático de retroalimentación

```powershell
.\.venv\Scripts\python.exe .\dt\active_loop.py --cycles 4 --points-per-cycle 50 --pool 6000 --ensemble-size 5 --epochs 800
```

El ciclo hace:

```text
entrenar -> seleccionar puntos inciertos/importantes -> correr SIMION -> reentrenar
```

## 7. Diseño inverso con el DT

```powershell
.\.venv\Scripts\python.exe .\dt\inverse_design.py --target-active 1.0 --target-forward 1.0 --minimize-theta-mean --minimize-theta-sigma --n-starts 256 --steps 800 --top-k 10
```

Valide en SIMION los candidatos del CSV:

```text
dt/data/inverse_candidates.csv
```

Validación numérica con SIMION/Lua:

```powershell
.\.venv\Scripts\python.exe .\dt\validate_candidates.py --top 5
```

## 8. Refinamiento angular local

```powershell
.\.venv\Scripts\python.exe .\dt\angular_refine_dataset.py --n 300
.\.venv\Scripts\python.exe .\dt\train_dt.py --ensemble-size 5 --epochs 1000
```
