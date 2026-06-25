# Automatización SIMION

## Optimizar cuatro voltajes

```powershell
python optimize_voltages.py
```

Configurar rangos, repeticiones y criterios de parada en `optimizer_config.json`.
Primero explora todo el espacio mediante lotes Latin Hypercube aleatorios, sin
usar el punto inicial. Continúa hasta estancamiento, promueve élites con más
repeticiones y después refina mediante búsqueda adaptativa por coordenadas. No
usa cantidad total fija de candidatos. Reportes SIMION son temporales y se
borran. Checkpoint y mejor resultado se guardan automáticamente.

```powershell
python optimize_voltages.py --resume
```

`Ctrl+C` conserva `optimization_checkpoint.json` y `optimization_result.json`.
El comando anterior continúa desde último candidato completo.

Desde raíz del proyecto, ejecución normal:

```powershell
python simion_run.py
```

`simion_run.py` vive en raÃ­z y usa rutas relativas al proyecto. Argumentos
adicionales se transmiten al comando interno, por ejemplo
`python simion_run.py --keep-report`.

## Ejecutar prueba completa

Guardar banco activo de SIMION como `exportado/experimento.iob`. En Data
Recording, configurar salida temporal a `../automation/runtime/transmision.csv`.
Luego:

```powershell
python automation/simion_automation.py run `
  --iob exportado/experimento.iob `
  --report automation/runtime/transmision.csv `
  --recording exportado/resultados.rec `
  --particles exportado/pruebaSimple41.fly2
```

El comando ejecuta `simion.exe --nogui fly`, sin interfaz ni renderizado,
analiza último `Fly'm`, imprime métricas y borra reporte temporal. No guarda log,
JSON ni historial. Timeout predeterminado: 10 min.

Para depuración solamente: `--keep-report`, `--output archivo.json` o
`--history archivo.jsonl`. Si una ejecución fallida deja reporte temporal, usar
`--replace-report` en siguiente intento.

## Analizar reporte

```powershell
python automation/simion_automation.py analyze Resultados/transmision.csv `
  --output Resultados/transmision_metricas.json
```

El parser usa el último bloque `Fly'm`, cuenta iones únicos detectados y calcula
transmisión, centroide, dispersión espacial, TOF y energía. Para un detector con
centro y radio conocidos:

```powershell
python automation/simion_automation.py analyze Resultados/transmision.csv `
  --target-x 875 --target-y 75 --aperture-radius 5
```

## Control de voltajes

`baseline_voltages.json` contiene condición que produjo 31/100 detecciones:
V2=-195 V, V3=45 V, V8=-1800 V, V14=1800 V y demás en 0 V.
`voltage_config.json` mantiene límites bloqueados en esos valores hasta definir
rangos físicos seguros.

1. Reemplazar límites y `max_step` con barandas físicas reales.
2. Guardar propuesta del optimizador como `candidate.json`:

```json
{"voltages": [41 valores numéricos]}
```

4. Validar antes de tocar SIMION:

```powershell
python automation/simion_automation.py prepare-voltages `
  automation/voltage_config.json automation/baseline_voltages.json
```

`voltage_control.lua` lee `automation/voltages.csv` y asigna
`adj_elect[1]` a `adj_elect[41]`. Debe adjuntarse como user program al banco de
trabajo `.iob`. Ejecutar SIMION desde raíz del proyecto para conservar ruta.

## Falta para cerrar bucle

Se necesita archivo `.iob` usado en prueba y voltajes actuales. Con eso se añade
runner batch: escribir voltajes -> ejecutar SIMION -> leer reporte -> registrar
objetivo -> proponer siguiente ensayo. Optimización bayesiana se conecta después
de definir objetivo y restricciones físicas.
