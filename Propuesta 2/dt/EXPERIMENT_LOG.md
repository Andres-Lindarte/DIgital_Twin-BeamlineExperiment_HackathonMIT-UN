# SIMION Digital Twin - registro de modificaciones y soluciones

Este archivo es el registro operativo para saber qué cambio funcionó, qué datos lo respaldan y cuál es la última solución validada. Mantenerlo corto: solo decisiones y resultados que afectan el reporte o la ruta experimental.

## Estado vigente

Fecha de registro: 2026-06-29

Dataset principal:

- `dt/data/dt_detector_window_dataset.csv`

Modelo vigente:

- `dt/models/baseline_mlp/`
- Entrenamiento: ensemble MLP, 5 modelos, 800 epochs.
- Targets actuales:
  - `detector_active_contact_fraction`
  - `detector_active_forward_fraction`
  - `detector_contact_angle_theta_mean_deg`
  - `detector_contact_angle_theta_sigma_deg`

Definición física vigente:

- Transmisión = impacto en la ventana activa del detector E19.
- Ángulo = solo impactos forward dentro de la ventana activa.
- Se descartó el uso de ángulos terminales de todos los iones porque contaminaba con valores `180°`.

## Última solución alta-transmisión validada

Fuente:

- `dt/data/inverse_validation.csv`

Resultado validado con SIMION/Lua, rank 1:

```text
active    = 100.0%
theta_mu  = 2.17053011°
theta_sig = 0.887447729°
theta_p95 = 3.600°
```

Voltajes:

```text
V1  = 500
V2  = 0
V3  = -885.394
V4  = 0
V5  = 0
V6  = -985.456
V7  = 0
V8  = 0
V9  = 989.454
V10 = 0.305
V11 = -33.685
V12 = -704.911
V13 = 0
V14 = 0
V15 = -184.825
V16 = 0
V17 = 0
V18 = -147.920
V19 = -2000
```

Notas:

- Esta solución reemplaza como mejor solución práctica a las elites previas de 100% con mayor incertidumbre angular.
- La calibración de `theta_sigma` mejoró tras refinamiento angular iterativo: el DT predijo cerca de `0.80°` y SIMION validó `0.87–0.92°`.

## Barrido inverso validado - rango medio

Fuente:

- `dt/data/inverse_sweep_fix_mid/summary.csv`

Mejor candidato por objetivo:

```text
target 50% -> SIMION 53.6%, theta_mu=5.481°, theta_sig=2.997°
target 65% -> SIMION 61.0%, theta_mu=4.046°, theta_sig=1.797°
target 80% -> SIMION 79.8%, theta_mu=3.292°, theta_sig=1.663°
```

Interpretación:

- `80%` quedó muy bien.
- `50%` quedó razonable después de ingerir falsos positivos.
- `65%` todavía está algo bajo; conviene repetir un ciclo enfocado en `50%` y `65%`.

## Barrido inverso validado - corrección 50/65

Fuente:

- `dt/data/inverse_sweep_fix_mid_b/summary.csv`

Mejor candidato por objetivo:

```text
target 50% -> SIMION 50.2%, theta_mu=4.658°, theta_sig=2.736°, theta_p95=9.347°
target 65% -> SIMION 61.4%, theta_mu=4.304°, theta_sig=2.011°, theta_p95=7.443°
```

Solución recomendada para 50%:

```text
V1  = 500
V2  = 0
V3  = -778.876
V4  = 0
V5  = 0
V6  = -808.925
V7  = 0
V8  = 0
V9  = 798.852
V10 = -172.719
V11 = -129.641
V12 = -903.291
V13 = 0
V14 = 0
V15 = -546.538
V16 = 0
V17 = 0
V18 = 66.368
V19 = -2000
```

Solución provisional para 65%:

```text
V1  = 500
V2  = 0
V3  = -878.915
V4  = 0
V5  = 0
V6  = -979.641
V7  = 0
V8  = 0
V9  = 913.987
V10 = -69.588
V11 = -56.213
V12 = -714.052
V13 = 0
V14 = 0
V15 = -16.622
V16 = 0
V17 = 0
V18 = -242.602
V19 = -2000
```

Interpretación:

- `50%` quedó resuelto: predicción 50.0%, SIMION 50.2%.
- `65%` sigue como frontera activa: el mejor candidato validado dio 61.4%; hay candidatos que saltan a 83.2% o caen a 42%, señal de rama múltiple o frontera abrupta.
- Próximo ciclo: ingerir `inverse_sweep_fix_mid_b`, reentrenar y repetir solo `65%`, validando más candidatos.

## Barrido inverso validado - corrección 65

Fuente:

- `dt/data/inverse_sweep_fix_65c/summary.csv`

Mejor candidato:

```text
target 65% -> pred 65.2% -> SIMION 65.6%
theta_mu  = 4.882°
theta_sig = 2.513°
theta_p95 = 9.550°
```

Solución recomendada para 65%:

```text
V1  = 500
V2  = 0
V3  = -695.973
V4  = 0
V5  = 0
V6  = -687.614
V7  = 0
V8  = 0
V9  = 962.197
V10 = -171.536
V11 = -196.357
V12 = -991.587
V13 = 0
V14 = 0
V15 = -227.033
V16 = 0
V17 = 0
V18 = -40.420
V19 = -2000
```

Interpretación:

- `65%` quedó resuelto en transmisión: error de +0.6 puntos porcentuales.
- El ángulo medio y sigma quedaron algo por encima del objetivo (`4.882°` y `2.513°`), pero dentro de una región físicamente coherente.
- Persisten ramas vecinas inestables: algunos candidatos predichos como `65%` validan en `70–82%`; por tanto esta zona debe tratarse como frontera abrupta/multirrama si se usa para diseño inverso fino.

## Barrido inverso denso - transmisión 45 a 100

Fuente:

- `dt/data/inverse_sweep_dense_v1/summary.csv`

Objetivo:

- Probar diseño inverso continuo para objetivos de transmisión no idénticos a los puntos ancla previos.
- Cada objetivo validó `top 3` candidatos con SIMION.

Mejor candidato por objetivo:

```text
target 45%  -> SIMION 53.6%,  theta_mu=3.471°, theta_sig=1.907°
target 50%  -> SIMION 53.6%,  theta_mu=5.035°, theta_sig=2.666°
target 55%  -> SIMION 58.6%,  theta_mu=5.333°, theta_sig=2.686°
target 60%  -> SIMION 61.0%,  theta_mu=5.253°, theta_sig=2.465°
target 65%  -> SIMION 67.6%,  theta_mu=4.769°, theta_sig=2.450°
target 70%  -> SIMION 69.6%,  theta_mu=4.770°, theta_sig=2.291°
target 75%  -> SIMION 74.0%,  theta_mu=4.925°, theta_sig=2.261°
target 80%  -> SIMION 78.8%,  theta_mu=2.887°, theta_sig=1.419°
target 85%  -> SIMION 81.0%,  theta_mu=3.392°, theta_sig=1.214°
target 90%  -> SIMION 91.4%,  theta_mu=3.554°, theta_sig=1.589°
target 95%  -> SIMION 98.6%,  theta_mu=2.541°, theta_sig=0.987°
target 100% -> SIMION 100.0%, theta_mu=2.301°, theta_sig=1.148°
```

Errores promedio usando el mejor candidato por objetivo:

```text
MAE transmisión = 2.58 puntos porcentuales
MAE theta_mu    = 0.34°
MAE theta_sig   = 0.23°
```

Interpretación:

- De `50%` a `100%`, el DT actúa como controlador inverso continuo razonable.
- `45%` sigue validando alto (`53.6%`), lo que sugiere un piso práctico cerca de `50%` para la familia de soluciones actual.
- No usar `45%` como ejemplo principal de control fino; sí usarlo como evidencia de frontera baja/familia viable.

## Clasificador de viabilidad agregado

Motivo:

- En la zona baja (`35–50%`) el regresor MLP suavizaba acantilados físicos y producía falsos positivos.
- Se implementó un clasificador separado para estimar si una configuración pertenece a una región con transmisión significativa.

Scripts:

- `dt/train_viability.py`
- Modificación en `dt/inverse_design.py`:
  - `--viability-model-dir`
  - `--min-viability-prob`
  - `--w-viability`
- Modificación en `dt/inverse_sweep.py` para pasar esos argumentos al diseño inverso.

Clasificador probado:

```powershell
.\.venv\Scripts\python.exe -u .\dt\train_viability.py --threshold 0.05 --ensemble-size 3 --epochs 300
```

Resultado de entrenamiento:

```text
accuracy ≈ 95–97%
falsos positivos de validación: 1–2 por modelo
```

Smoke test con viabilidad:

Fuente:

- `dt/data/inverse_sweep_viability_smoke/summary.csv`

```text
target 45% -> pred 45.7% -> SIMION 42.6%
theta_mu  = 5.027°
theta_sig = 1.431°
theta_p95 = 7.097°
```

Interpretación:

- La penalización de viabilidad corrigió la zona baja: antes `45%` validaba cerca de `53.6%` o aparecían falsos positivos severos; con viabilidad validó `42.6%`.
- Próximo paso recomendado: repetir barrido denso bajo/medio usando el clasificador.

Comando sugerido:

```powershell
.\.venv\Scripts\python.exe -u .\dt\inverse_sweep.py `
  --case v40,0.40,5.5,2.8 `
  --case v45,0.45,5.0,2.5 `
  --case v50,0.50,5.0,2.5 `
  --case v55,0.55,5.0,2.5 `
  --case v60,0.60,5.0,2.5 `
  --case v65,0.65,4.5,2.0 `
  --case v70,0.70,4.5,2.0 `
  --steps 700 `
  --n-starts 256 `
  --top-k 10 `
  --validate-top 3 `
  --out-dir .\dt\data\inverse_sweep_viability_v1 `
  --viability-model-dir .\dt\models\viability_mlp `
  --min-viability-prob 0.75 `
  --w-viability 8.0
```

## Barrido con clasificador de viabilidad - 40 a 70

Fuente:

- `dt/data/inverse_sweep_viability_v1/summary.csv`

Mejor candidato por objetivo:

```text
target 40% -> SIMION 52.0%, theta_mu=4.35°, theta_sig=2.63°
target 45% -> SIMION 47.4%, theta_mu=4.58°, theta_sig=1.86°
target 50% -> SIMION 50.0%, theta_mu=4.97°, theta_sig=2.79°
target 55% -> SIMION 53.0%, theta_mu=4.82°, theta_sig=1.68°
target 60% -> SIMION 65.4%, theta_mu=4.42°, theta_sig=1.98°
target 65% -> SIMION 63.8%, theta_mu=4.21°, theta_sig=1.66°
target 70% -> SIMION 69.6%, theta_mu=4.81°, theta_sig=2.19°
```

Errores promedio usando el mejor candidato por objetivo:

```text
MAE transmisión = 3.34 puntos porcentuales
MAE theta_mu    = 0.42°
MAE theta_sig   = 0.42°
```

Interpretación:

- `45–55%` quedó controlado razonablemente.
- `65–70%` quedó razonable.
- `40%` sigue validando demasiado alto (`52%`), lo que sugiere que la familia viable actual tiene un piso práctico cercano a `45–50%`.
- `60%` quedó alto (`65.4%`) y debe entrar como dato de corrección si se requiere control fino en ese punto.
- El clasificador de viabilidad redujo falsos positivos catastróficos, pero no resuelve por sí solo el control fino por debajo de `45%`.

## Alimentación fuerte zona baja - 30 a 50

Fuente:

- `dt/data/inverse_sweep_low_feed_v1/summary.csv`

Objetivo:

- Alimentar y validar intensivamente la zona baja de transmisión (`30–50%`) con `top 12` candidatos por objetivo.

Mejor candidato por objetivo:

```text
target 30% -> pred 30.3% -> SIMION 31.6%, theta_mu=7.946°, theta_sig=4.620°, theta_p95=12.367°
target 35% -> pred 35.1% -> SIMION 35.8%, theta_mu=6.246°, theta_sig=2.732°, theta_p95=11.135°
target 40% -> pred 40.0% -> SIMION 39.2%, theta_mu=6.232°, theta_sig=2.617°, theta_p95=10.785°
target 45% -> pred 45.1% -> SIMION 44.4%, theta_mu=5.002°, theta_sig=2.496°, theta_p95=9.024°
target 50% -> pred 50.1% -> SIMION 50.4%, theta_mu=5.048°, theta_sig=2.494°, theta_p95=9.282°
```

Errores promedio usando el mejor candidato por objetivo:

```text
MAE transmisión = 0.84 puntos porcentuales
MAE theta_mu    = 0.49°
MAE theta_sig   = 0.38°
```

Soluciones recomendadas:

```text
30%: V3=-978.976 V6=-599.806 V9=208.118 V10=-3.727   V11=155.703  V12=-749.234 V15=-156.154 V18=-509.269
35%: V3=-887.635 V6=-858.038 V9=619.585 V10=-104.970 V11=-42.620  V12=-759.942 V15=185.834  V18=-531.734
40%: V3=-864.536 V6=-910.071 V9=597.976 V10=-83.674  V11=-32.649  V12=-727.207 V15=179.254  V18=-493.339
45%: V3=-693.212 V6=-717.019 V9=930.969 V10=-192.592 V11=-150.933 V12=-927.522 V15=-389.124 V18=-136.284
50%: V3=-876.728 V6=-971.292 V9=853.519 V10=-91.426  V11=-66.875  V12=-728.566 V15=263.262  V18=-431.235
```

Interpretación:

- La alimentación intensiva sí bajó el límite funcional: ahora hay soluciones validadas para `30–50%`.
- `30%` existe, pero con peor calidad angular (`theta_mu≈7.95°`, `theta_sig≈4.62°`), así que debe tratarse como régimen bajo más degradado.
- `35–50%` quedó bien controlado en transmisión y razonable en ángulo.
- Con este resultado, el DT ya cubre diseño inverso validado aproximadamente de `30–100%`, con calidad angular decreciente hacia baja transmisión.

## Alimentación fuerte zona muy baja - 20 a 40

Fuente:

- `dt/data/inverse_sweep_low_feed_v2/summary.csv`

Objetivo:

- Probar si la familia baja puede expandirse desde `30%` hacia `20–25%`.

Mejor candidato por objetivo:

```text
target 20% -> pred 20.0% -> SIMION 19.0%, theta_mu=9.237°, theta_sig=6.189°, theta_p95=17.543°
target 25% -> pred 25.1% -> SIMION 24.2%, theta_mu=6.458°, theta_sig=3.085°, theta_p95=10.188°
target 30% -> pred 30.1% -> SIMION 30.4%, theta_mu=5.651°, theta_sig=2.739°, theta_p95=10.075°
target 35% -> pred 35.0% -> SIMION 35.0%, theta_mu=8.334°, theta_sig=3.909°, theta_p95=14.819°
target 40% -> pred 40.4% -> SIMION 40.6%, theta_mu=5.556°, theta_sig=2.922°, theta_p95=10.315°
```

Errores promedio usando el mejor candidato por objetivo:

```text
MAE transmisión = 0.56 puntos porcentuales
MAE theta_mu    = 1.20°
MAE theta_sig   = 0.88°
```

Soluciones recomendadas:

```text
20%: V3=-576.029 V6=-858.412 V9=182.369 V10=92.668  V11=241.963 V12=-423.020 V15=191.604 V18=-561.172
25%: V3=-955.276 V6=-610.510 V9=658.796 V10=100.897 V11=106.548 V12=-760.538 V15=262.983 V18=-195.386
30%: V3=-733.842 V6=-814.427 V9=524.338 V10=105.613 V11=-75.460 V12=-759.759 V15=562.062 V18=-283.270
35%: V3=-968.071 V6=-846.077 V9=497.165 V10=-2.636  V11=187.679 V12=-592.162 V15=231.486 V18=-232.258
40%: V3=-973.854 V6=-655.090 V9=93.457  V10=83.843  V11=132.497 V12=-467.252 V15=114.576 V18=-444.049
```

Interpretación:

- La transmisión ahora queda controlada desde `20%` hasta `100%`.
- La calidad angular se degrada claramente en el extremo bajo, sobre todo en `20%` y algunos `35%`.
- Esto sugiere que sí existe familia de baja transmisión, pero se obtiene mediante clipping/selección fuerte del haz; no debe presentarse como igual de limpia que la familia de alta transmisión.
- Para transmisión, el DT ya funciona como controlador inverso amplio (`20–100%`). Para calidad angular, la confiabilidad fuerte empieza aproximadamente en `30–40%` y mejora hacia alta transmisión.

## Prueba de objetivo idealizado 100%, theta 0, sigma 0.5

Fuente:

- `dt/data/inverse_sweep_perfect100/summary.csv`

Objetivo solicitado:

```text
active=100%, theta_mu=0°, theta_sig=0.5°
```

Validación:

```text
rank 1: pred active=97.9% -> SIMION 91.8%, theta_mu=1.687°, theta_sig=1.100°
rank 3: pred active=97.9% -> SIMION 92.0%, theta_mu=1.673°, theta_sig=0.990°
rank 5: pred active=97.9% -> SIMION 92.4%, theta_mu=1.720°, theta_sig=1.147°
```

Interpretación:

- El objetivo idealizado no parece alcanzable con los pesos actuales: el inversor sacrificó transmisión para bajar ángulo.
- El mejor compromiso físico ya validado para transmisión 100% sigue cerca de `theta_mu≈2.17°`, `theta_sig≈0.89°`.
- Si se requiere transmisión estrictamente 100%, el diseño inverso debe usar una penalización más dura para `active=1.0` o un filtro posterior que descarte candidatos por debajo de 99–100%.

## Aprendizaje activo recurrente con viabilidad

Motivo:

- Después de resolver el rango `20–100%`, el siguiente paso es que el DT solicite puntos donde más puede aprender, no solamente donde el usuario fije objetivos.

Cambios:

- `dt/active_select.py`
  - Usa ensemble de regresión + clasificador de viabilidad.
  - La adquisición combina:
    - incertidumbre de transmisión;
    - incertidumbre angular;
    - cercanía a fronteras de transmisión;
    - incertidumbre de viabilidad;
    - desacuerdo entre regresor y clasificador.
  - Recorta internamente la predicción de contacto a `[0, 1]` para evitar artefactos.
- `dt/active_loop.py`
  - Ahora reentrena `train_dt.py` y `train_viability.py` en cada ciclo.
- `dt/validate_candidates.py`
  - Conserva columnas `pred_viability_prob` y `unc_viability_prob` si vienen de candidatos inversos.

Smoke test:

```powershell
.\.venv\Scripts\python.exe -u .\dt\active_select.py --pool 200 --select 5 --out .\dt\data\active_candidates_smoke.csv
```

Resultado:

- El selector priorizó candidatos en bordes de viabilidad (`viab≈0.48–0.62`) y transmisiones predichas bajas/medias, que son justo las regiones informativas.

Comando recomendado para iniciar aprendizaje activo recurrente:

```powershell
.\.venv\Scripts\python.exe -u .\dt\active_loop.py --cycles 3 --points-per-cycle 40 --pool 5000 --ensemble-size 5 --epochs 800 --viability-ensemble-size 5 --viability-epochs 500
```

## Ciclo activo con viabilidad - 50 puntos

Fuente:

- `dt/models/active_loop_summary.json`
- `dt/data/active_candidates_cycle_01.csv`
- `dt/data/dt_detector_window_dataset.csv`

Comando usado:

```powershell
.\.venv\Scripts\python.exe -u .\dt\active_loop.py --cycles 1 --points-per-cycle 50 --pool 5000 --ensemble-size 5 --epochs 800 --viability-ensemble-size 5 --viability-epochs 500
```

Dónde pidió puntos:

```text
Predicción de active en candidatos:
0–20%   : 12 puntos
20–40%  : 20 puntos
40–60%  : 15 puntos
60–80%  : 2 puntos
80–100% : 0 puntos

Resultados SIMION reales de los 50 puntos:
0–20%   : 21 puntos
20–40%  : 9 puntos
40–60%  : 13 puntos
60–80%  : 7 puntos
80–100% : 0 puntos
```

Interpretación:

- El selector activo se concentró en la frontera baja/media (`0–60%`) y bordes de viabilidad (`viab≈0.5`), que son las zonas más informativas.
- No pidió puntos de alta transmisión, lo cual es correcto si el objetivo era aprender frontera/ángulo en baja transmisión, pero no mejora mucho las métricas high-contact.

Cambio en métricas de entrenamiento antes/después:

```text
high-contact contact MAE     : 0.0168 -> 0.0200
high-contact theta_mean MAE  : 0.1612 -> 0.1641
high-contact theta_sigma MAE : 0.1570 -> 0.1528
global contact MAE           : 0.0452 -> 0.0481
global theta_sigma MAE       : 0.6102 -> 0.6465
```

Conclusión:

- Hubo una mejora pequeña en `theta_sigma` high-contact, pero no una mejora global inmediata.
- El valor principal del ciclo fue agregar ejemplos difíciles de baja/media transmisión con dispersión angular alta (`theta_sig≈4–5°`), necesarios para que el modelo deje de suavizar fronteras.
- El siguiente paso debe evaluar si esos datos mejoran el diseño inverso bajo/medio; no basta con mirar la métrica global de entrenamiento.

## Diagnóstico de velocidad en impactos válidos

Motivo:

- Antes de agregar emitancia u otras métricas de fase, se verificó si la magnitud de la velocidad cambia entre iones o si la variación de `vz` está dominada por la distribución angular.

Cambios:

- `Hackathon_student/Hackathon_student/SimpleSetUp.lua`
  - Agrega `DETECTOR_CONTACT_SPEED_SUMMARY`.
- `optimize.py`
  - Agrega parser `parse_detector_contact_speed_summary`.

Métricas nuevas:

```text
detector_contact_speed_count
detector_contact_speed_speed_mean
detector_contact_speed_speed_sigma
detector_contact_speed_speed_rel_sigma
detector_contact_speed_speed_min
detector_contact_speed_speed_max
detector_contact_speed_vz_mean
detector_contact_speed_vz_sigma
detector_contact_speed_vz_rel_sigma
detector_contact_speed_vz_min
detector_contact_speed_vz_max
```

Prueba en solución de alta transmisión:

```text
active = 100%
theta_mu = 2.133°
theta_sig = 0.899°
speed_mean = 130.607952
speed_sigma = 0.025724
speed_rel_sigma = 0.000197
vz_mean = 130.501381
vz_sigma = 0.080328
vz_rel_sigma = 0.000616
```

Prueba en solución baja:

```text
active ≈ 15.8%
theta_mu = 10.400°
theta_sig = 6.606°
speed_mean = 130.603066
speed_sigma = 0.207879
speed_rel_sigma = 0.001592
vz_mean = 127.616169
vz_sigma = 3.937170
vz_rel_sigma = 0.030852
```

Interpretación:

- La magnitud total de velocidad es casi constante incluso en baja transmisión (`speed_rel_sigma` del orden de `0.02%–0.16%`).
- La componente longitudinal `vz` sí se dispersa mucho más en baja transmisión, consistente con el aumento de ángulo.
- Por tanto, una distribución de velocidades totales probablemente aporta poca información adicional como target; la distribución de `vz` está fuertemente ligada a la distribución angular.
- Para emitancia, parece razonable usar ángulos/direcciones normalizadas sin modelar una distribución energética independiente, al menos en esta configuración.

## Falla detectada y corrección aplicada

Problema:

- El DT proponía soluciones para `35%` de transmisión que predijo como viables, pero SIMION validó cerca de `0%`.

Evidencia:

- `dt/data/inverse_sweep_fix_low/01_fix35_validation.csv`

Corrección:

```powershell
.\.venv\Scripts\python.exe .\dt\ingest_validations.py --source .\dt\data\inverse_sweep_fix_low
```

Resultado:

```text
Ingeridas: 4; omitidas por duplicado: 25; fuentes: 9
```

Interpretación:

- Esas 4 filas son falsos positivos de alto valor: enseñan al DT que una región predicha como `35%` en realidad pertenece a la zona de transmisión casi cero.

## Comandos recomendados para el siguiente ciclo

Ingerir validaciones del barrido medio:

```powershell
.\.venv\Scripts\python.exe .\dt\ingest_validations.py --source .\dt\data\inverse_sweep_fix_mid
```

Reentrenar:

```powershell
.\.venv\Scripts\python.exe -u .\dt\train_dt.py --ensemble-size 5 --epochs 800
```

Repetir solo objetivos que aún fallan:

```powershell
.\.venv\Scripts\python.exe -u .\dt\inverse_sweep.py --case fix50b,0.50,5.0,2.5 --case fix65b,0.65,4.5,2.0 --steps 700 --n-starts 256 --top-k 12 --validate-top 6 --out-dir .\dt\data\inverse_sweep_fix_mid_b
```

Siguiente ciclo sugerido tras `fix_mid_b`:

```powershell
.\.venv\Scripts\python.exe .\dt\ingest_validations.py --source .\dt\data\inverse_sweep_fix_mid_b
.\.venv\Scripts\python.exe -u .\dt\train_dt.py --ensemble-size 5 --epochs 800
.\.venv\Scripts\python.exe -u .\dt\inverse_sweep.py --case fix65c,0.65,4.5,2.0 --steps 800 --n-starts 320 --top-k 16 --validate-top 8 --out-dir .\dt\data\inverse_sweep_fix_65c
```

## Scripts agregados/modificados

- `dt/inverse_sweep.py`
  - Ejecuta barridos de diseño inverso con objetivos variados y valida con SIMION.
  - Produce carpetas con candidatos, validaciones y `summary.csv`.

- `dt/ingest_validations.py`
  - Convierte validaciones SIMION ya realizadas en filas del dataset principal.
  - Cierra el loop de aprendizaje: error detectado -> dataset -> reentrenamiento.

- `dt/inverse_design.py`
  - Se agregó `--no-minimize-theta-sigma` para permitir pedir una sigma objetivo sin forzar simultáneamente sigma mínima.

- `dt/angular_refine_dataset.py`
  - Ahora usa como semillas todos los `inverse_candidates*.csv` e `inverse_validation*.csv`, no solo el último archivo.

## Diagnostico de velocidades reales vs estimadas por angulo

Motivo:

- Decidir si el DT necesita predecir una metrica adicional de velocidad, o si se puede derivar "gratis" desde la rapidez casi constante y las metricas angulares.

Cambios temporales/agregados:

- `Hackathon_student/Hackathon_student/SimpleSetUp.lua`
  - Agrega `DETECTOR_CONTACT_SPEED_SUMMARY` para contactos validos/forward en la ventana activa.
  - Reporta rapidez total, velocidad transversal `vperp = sqrt(vx^2 + vy^2)` y componente `vz`.
  - Se separo `reset_contact_stats()` para evitar el limite Lua de mas de 60 upvalues por funcion.
- `optimize.py`
  - Parseo de `DETECTOR_CONTACT_SPEED_SUMMARY`.
- `dt/velocity_diagnostic.py`
  - Recorre candidatos validados en distinto rango angular.
  - Compara valores reales SIMION contra estimaciones:
    - `vperp_mean ~= speed_mean * sin(theta_mean)`
    - `vperp_sigma ~= speed_mean * theta_sigma_rad`
    - `vz_mean ~= speed_mean * cos(theta_mean)`

Comando usado:

```powershell
.\.venv\Scripts\python.exe -u .\dt\velocity_diagnostic.py --limit 16 --out .\dt\data\velocity_diagnostic.csv
```

Rango evaluado:

```text
theta_mean: 2.12 deg a 11.75 deg
speed_mean: 130.589316 a 130.656961
speed_rel_sigma: 0.019% a 0.124%
```

Resumen de error:

```text
vperp_mean:  MAE 0.0232, max 0.0540, mean rel 0.164%, max rel 0.417%
vperp_sigma: MAE 0.0851, max 0.2431, mean rel 1.17%,  max rel 2.76%
vz_mean:     MAE 0.1679, max 0.3181, mean rel 0.130%, max rel 0.247%
vz_sigma:    MAE 0.2607, max 1.0320
```

Interpretacion:

- La rapidez total de los iones es practicamente constante para esta configuracion del reto.
- La velocidad transversal `vperp` se deriva muy bien desde `theta_mean` y `theta_sigma`; no justifica agregar otro target al DT.
- `vz_mean` tambien se estima bien desde `speed*cos(theta_mean)`.
- `vz_sigma` es menos robusta con la aproximacion simple, sobre todo cuando la dispersion angular es baja; si alguna vez se necesita como metrica de reporte, conviene calcularla como metrica derivada aproximada, no usarla como target principal.

Decision:

- No agregar distribucion de velocidades como target entrenado por ahora.
- Mantener el DT con transmision activa + media/sigma angular.
- Agregar, si hace falta para presentacion o reporte, metricas derivadas:
  - `speed0 ~= 130.62`
  - `vperp_mean ~= speed0 * sin(theta_mean)`
  - `vperp_sigma ~= speed0 * theta_sigma_rad`
  - `vz_mean ~= speed0 * cos(theta_mean)`

## Actualizacion: `vz_sigma` como metrica derivada + residual aprendido

Decision posterior:

- Incluir `vz_sigma` porque es fisicamente relevante y casi gratis.
- No entrenar `vz_sigma` completo como caja negra.
- Entrenar solo el residual respecto a una base fisica:

```text
vz_sigma_pred = vz_sigma_physics(theta_mean, theta_sigma, speed0) + residual_DT
```

Base fisica usada:

```text
theta ~ Normal(theta_mean, theta_sigma)
vz = speed0 * cos(theta)
speed0 ~= 130.62
```

Implementacion:

- `dt/derived_metrics.py`
  - Calcula `derived_vz_mean`, `derived_vz_sigma_physics` y residual.
- `dt/dt_config.json`
  - Agrega target auxiliar `derived_vz_sigma_residual`.
- `dt/train_dt.py`
  - Entrenamiento con mascara por target.
  - Las filas viejas entrenan transmision/angulos.
  - Solo filas con `detector_contact_speed_vz_sigma` entrenan `derived_vz_sigma_residual`.
- `dt/predict_dt.py`
  - Reporta `derived_vz_mean`, `derived_vz_sigma_physics`, `derived_vz_sigma_corrected`.
- `dt/inverse_design.py` y `dt/active_select.py`
  - Agregan esas metricas derivadas a candidatos.
- `dt/validate_candidates.py`
  - Guarda `sim_speed_mean`, `sim_vz_mean`, `sim_vz_sigma` y residual observado.
- `dt/ingest_validations.py`
  - Ingiere validaciones nuevas con columnas de velocidad si existen.

Estado del dataset al implementar:

```text
filas totales: 1586
filas con derived_vz_sigma_residual observado: 16
residual min/max/media: -0.1517 / 0.9589 / 0.1711
```

Validacion tecnica:

```text
py_compile OK
entrenamiento de humo OK en dt/models/_smoke_vz_residual
predict_dt expone derived_vz_sigma_corrected
```

## Backfill masivo de residual `vz_sigma`

Objetivo:

- Recalcular puntos existentes para agregar `detector_contact_speed_vz_sigma` sin sesgar el dataset hacia puntos nuevos de baja transmision.
- Balancear el residual en todo el rango de transmision, especialmente 80--100%, que casi no tenia datos de residual.

Comando usado:

```powershell
.\.venv\Scripts\python.exe -u .\dt\backfill_velocity_marathon.py --n 1550 --batch-size 100 --train-every 500 --epochs 800 --viability-epochs 500
```

Resultado:

```text
requested_n: 1550
done: 1521
batches: 17
rows: 3272
residual_rows: 1702
eligible_remaining_unique: 0
```

Interpretacion:

- El backfill no llego exactamente a 1550 porque se agotaron los puntos unicos elegibles.
- Aunque quedan filas antiguas sin residual, sus voltajes ya tienen una fila duplicada/recalculada con residual. Por eso `eligible_remaining_unique = 0`.

Cobertura final de residual por transmision:

```text
0--1%:     n=271, residual_mean=0.006
1--10%:    n=100, residual_mean=0.476
10--40%:   n=231, residual_mean=0.514
40--80%:   n=470, residual_mean=0.337
80--98%:   n=111, residual_mean=0.206
98--100%:  n=519, residual_mean=0.036
```

Metricas promedio tras reentrenamiento:

```text
contact global MAE:          0.0302
contact high-contact MAE:    0.0148
theta_mean global MAE:       0.7834 deg
theta_mean high-contact MAE: 0.1171 deg
theta_sigma global MAE:      0.4829 deg
theta_sigma high-contact MAE:0.1165 deg
vz residual global MAE:      0.1606
vz residual high-contact MAE:0.0483
```

Decision:

- El residual `vz_sigma` ya esta suficientemente balanceado para usarlo como salida auxiliar del DT.
- No seguir backfill de puntos existentes: no quedan voltajes unicos elegibles.
- Siguiente paso recomendado: validar con barrido inverso o candidatos nuevos, no mas backfill.
