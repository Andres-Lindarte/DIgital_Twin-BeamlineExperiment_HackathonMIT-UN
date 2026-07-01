from __future__ import annotations

import csv
import json
import math
from datetime import datetime
from pathlib import Path
from textwrap import dedent

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    Image as RLImage,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reportes" / "sistema_actual_dt"
OUT.mkdir(parents=True, exist_ok=True)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def avg_metric(summary: dict, group: str, key: str) -> float | None:
    vals = []
    for model in summary.get("models", []):
        value = model.get(group, {}).get(key)
        if value is not None and math.isfinite(float(value)):
            vals.append(float(value))
    return None if not vals else sum(vals) / len(vals)


def fmt(value: float | None, nd: int = 3) -> str:
    if value is None:
        return "n/d"
    return f"{value:.{nd}f}"


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def make_bar_chart(
    data: list[tuple[str, float]],
    title: str,
    out: Path,
    y_label: str = "conteo",
    width: int = 1100,
    height: int = 560,
) -> None:
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)
    try:
        font_title = ImageFont.truetype("arial.ttf", 30)
        font = ImageFont.truetype("arial.ttf", 22)
        small = ImageFont.truetype("arial.ttf", 18)
    except Exception:
        font_title = font = small = ImageFont.load_default()
    margin_l, margin_r, margin_t, margin_b = 95, 35, 80, 105
    plot_w = width - margin_l - margin_r
    plot_h = height - margin_t - margin_b
    max_v = max([v for _, v in data] + [1.0])
    draw.text((width // 2, 25), title, fill=(30, 30, 30), font=font_title, anchor="ma")
    draw.line((margin_l, margin_t, margin_l, margin_t + plot_h), fill=(60, 60, 60), width=2)
    draw.line((margin_l, margin_t + plot_h, margin_l + plot_w, margin_t + plot_h), fill=(60, 60, 60), width=2)
    draw.text((18, margin_t + plot_h // 2), y_label, fill=(60, 60, 60), font=small)
    bar_gap = 18
    bar_w = max(24, (plot_w - bar_gap * (len(data) + 1)) // max(1, len(data)))
    for i, (label, value) in enumerate(data):
        x0 = margin_l + bar_gap + i * (bar_w + bar_gap)
        h = int(plot_h * value / max_v)
        y0 = margin_t + plot_h - h
        color = (58, 121, 191) if i % 2 == 0 else (81, 153, 106)
        draw.rectangle((x0, y0, x0 + bar_w, margin_t + plot_h), fill=color)
        draw.text((x0 + bar_w / 2, y0 - 8), str(int(value)), fill=(30, 30, 30), font=small, anchor="ms")
        draw.text((x0 + bar_w / 2, margin_t + plot_h + 18), label, fill=(30, 30, 30), font=small, anchor="ma")
    img.save(out)


def make_line_chart(
    series: list[tuple[int, float]],
    title: str,
    out: Path,
    y_label: str,
    width: int = 1100,
    height: int = 560,
) -> None:
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)
    try:
        font_title = ImageFont.truetype("arial.ttf", 30)
        small = ImageFont.truetype("arial.ttf", 18)
    except Exception:
        font_title = small = ImageFont.load_default()
    margin_l, margin_r, margin_t, margin_b = 105, 45, 80, 90
    plot_w = width - margin_l - margin_r
    plot_h = height - margin_t - margin_b
    xs = [x for x, _ in series]
    ys = [y for _, y in series]
    x_min, x_max = min(xs), max(xs)
    y_min, y_max = 0.0, max(ys) * 1.1
    draw.text((width // 2, 25), title, fill=(30, 30, 30), font=font_title, anchor="ma")
    draw.line((margin_l, margin_t, margin_l, margin_t + plot_h), fill=(60, 60, 60), width=2)
    draw.line((margin_l, margin_t + plot_h, margin_l + plot_w, margin_t + plot_h), fill=(60, 60, 60), width=2)
    draw.text((18, margin_t + plot_h // 2), y_label, fill=(60, 60, 60), font=small)

    def sx(x: int) -> float:
        return margin_l + (x - x_min) / max(1, x_max - x_min) * plot_w

    def sy(y: float) -> float:
        return margin_t + plot_h - (y - y_min) / max(1e-9, y_max - y_min) * plot_h

    pts = [(sx(x), sy(y)) for x, y in series]
    if len(pts) > 1:
        draw.line(pts, fill=(200, 80, 60), width=4)
    for (x, y), (px, py) in zip(series, pts):
        draw.ellipse((px - 6, py - 6, px + 6, py + 6), fill=(200, 80, 60))
        draw.text((px, py - 14), f"{100*y:.1f} pp", fill=(30, 30, 30), font=small, anchor="ms")
        draw.text((px, margin_t + plot_h + 20), str(x), fill=(30, 30, 30), font=small, anchor="ma")
    img.save(out)


def p(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text.replace("\n", " "), style)


def bullet(items: list[str], style: ParagraphStyle) -> ListFlowable:
    return ListFlowable([ListItem(p(item, style), bulletColor=colors.HexColor("#333333")) for item in items], bulletType="bullet")


def page_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.grey)
    canvas.drawString(0.65 * inch, 0.38 * inch, "Reporte interno - Digital Twin SIMION")
    canvas.drawRightString(7.85 * inch, 0.38 * inch, f"Página {doc.page}")
    canvas.restoreState()


def build_pdf(pdf_path: Path, figures: dict[str, Path], tables: dict[str, list[list[str]]], meta: dict) -> None:
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="TitleCenter", parent=styles["Title"], alignment=TA_CENTER, fontSize=19, leading=24, spaceAfter=10))
    styles.add(ParagraphStyle(name="SubTitle", parent=styles["Normal"], alignment=TA_CENTER, fontSize=10.5, leading=14, textColor=colors.HexColor("#555555"), spaceAfter=18))
    styles.add(ParagraphStyle(name="H1x", parent=styles["Heading1"], fontSize=15, leading=19, spaceBefore=14, spaceAfter=8, textColor=colors.HexColor("#1f4e79")))
    styles.add(ParagraphStyle(name="H2x", parent=styles["Heading2"], fontSize=12.5, leading=15, spaceBefore=9, spaceAfter=5, textColor=colors.HexColor("#2f6f4e")))
    styles.add(ParagraphStyle(name="BodyJ", parent=styles["BodyText"], alignment=TA_JUSTIFY, fontSize=9.4, leading=12.5, spaceAfter=6))
    styles.add(ParagraphStyle(name="Small", parent=styles["BodyText"], fontSize=8.2, leading=10.4, spaceAfter=4))
    styles.add(ParagraphStyle(name="Box", parent=styles["BodyText"], fontSize=9, leading=12, backColor=colors.HexColor("#eef5fb"), borderColor=colors.HexColor("#7aa6c2"), borderWidth=0.5, borderPadding=6, spaceAfter=8))

    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=letter,
        rightMargin=0.58 * inch,
        leftMargin=0.58 * inch,
        topMargin=0.62 * inch,
        bottomMargin=0.62 * inch,
        title="Reporte del sistema actual DT SIMION",
    )
    story = []
    story.append(Paragraph("Reporte del sistema actual de Gemelo Digital SIMION", styles["TitleCenter"]))
    story.append(Paragraph("Versión interna para poner al grupo al día", styles["SubTitle"]))
    story.append(p(f"Fecha de generación: {meta['date']}. Este documento describe la versión actual elegida del sistema: emulación por ensemble MLP diferenciable, diseño inverso por gradiente y recolección activa orientada a información útil.", styles["Box"]))

    story.append(Paragraph("1. Resumen ejecutivo", styles["H1x"]))
    story.append(p("Construimos un gemelo digital del beamline de SIMION. En palabras simples: una red neuronal aprende a imitar el resultado de SIMION a partir de los voltajes de control. Una vez entrenado, el gemelo responde en milisegundos, se puede derivar y permite buscar voltajes sin pagar una corrida completa de SIMION en cada intento.", styles["BodyJ"]))
    story.append(bullet([
        "Entrada del modelo: ocho voltajes libres del montaje.",
        "Salidas principales: transmisión activa, fracción forward, ángulo medio de impacto, dispersión angular y una corrección residual para la dispersión de velocidad longitudinal.",
        "Uso directo: dados unos voltajes, predice las métricas del haz.",
        "Uso inverso: dada una consigna de transmisión/ángulo, optimiza los voltajes de entrada sobre el propio gemelo y luego valida en SIMION.",
        "Fortaleza actual: buena predicción cerca de la región informativa y control inverso validado de transmisión en un rango amplio.",
        "Cuidado principal: las regiones de baja transmisión son físicamente más abruptas y tienen peor calidad angular; el gemelo debe reportar incertidumbre y no venderlas como iguales a la región de alta transmisión.",
    ], styles["BodyJ"]))

    story.append(Paragraph("2. Qué problema resuelve", styles["H1x"]))
    story.append(p("El reto pide un emulador que reciba voltajes y devuelva una o varias cantidades de interés del beamline. Nuestro sistema no busca reemplazar SIMION para siempre: busca usar SIMION como fuente de datos cara, aprender una aproximación rápida y usar esa aproximación para control.", styles["BodyJ"]))
    story.append(p("El haz de entrada se mantiene fijo en el reto: misma partícula, energía y distribución inicial. Por eso el cambio en las métricas se atribuye a los voltajes. Esto simplifica el problema: el gemelo no necesita generalizar todavía a masa/carga o energía distinta.", styles["BodyJ"]))

    story.append(Paragraph("3. Variables del sistema", styles["H1x"]))
    story.append(Paragraph("3.1 Voltajes de entrada", styles["H2x"]))
    story.append(p("El modelo trabaja con los ocho voltajes libres indicados por la guía del reto: V3, V6, V9, V10, V11, V12, V15 y V18. El resto se mantiene fijo, por ejemplo V1=500 V y V19=-2000 V para el detector.", styles["BodyJ"]))
    input_table = [["Tipo", "Variables"], ["Voltajes libres", "V3, V6, V9, V10, V11, V12, V15, V18"], ["Voltajes fijos", "V1=500, V2=0, V4=0, V5=0, V7=0, V8=0, V13=0, V14=0, V16=0, V17=0, V19=-2000"]]
    story.append(make_table(input_table, [1.4 * inch, 5.9 * inch]))

    story.append(Paragraph("3.2 Métricas de salida", styles["H2x"]))
    metric_table = [
        ["Métrica", "Qué significa", "Uso"],
        ["transmisión activa", "fracción de iones que impactan la ventana activa del detector", "objetivo principal"],
        ["forward fraction", "fracción que llega con dirección válida", "admisibilidad física"],
        ["theta_mean", "ángulo medio de impacto", "calidad del haz"],
        ["theta_sigma", "dispersión angular", "enfoque/paralelismo"],
        ["vz_sigma residual", "corrección aprendida sobre una fórmula física simple", "salida auxiliar de velocidad"],
    ]
    story.append(make_table(metric_table, [1.35 * inch, 3.4 * inch, 2.2 * inch], small=True))

    story.append(Paragraph("4. Cómo corre el sistema completo", styles["H1x"]))
    story.append(p("El flujo tiene cinco capas. La primera habla con SIMION; la segunda guarda datos; la tercera entrena el gemelo; la cuarta usa el gemelo para predecir; y la quinta usa gradientes para diseño inverso.", styles["BodyJ"]))
    flow_table = [
        ["Etapa", "Qué hace", "Archivo principal"],
        ["SIMION/Lua", "Vuela iones, calcula impactos y métricas", "SimpleSetUp.lua / optimize.py"],
        ["Dataset", "Guarda voltajes y métricas reales", "dt/data/dt_detector_window_dataset.csv"],
        ["Entrenamiento", "Ajusta ensemble MLP por backpropagation", "dt/train_dt.py"],
        ["Predicción", "Voltajes -> métricas predichas + incertidumbre", "dt/predict_dt.py"],
        ["Control inverso", "Consigna -> voltajes candidatos", "dt/inverse_design.py"],
        ["Validación", "Candidatos -> SIMION real", "dt/validate_candidates.py"],
        ["Aprendizaje activo", "Pide nuevos puntos donde el modelo falla o duda", "dt/*active*.py"],
    ]
    story.append(make_table(flow_table, [1.15 * inch, 4.2 * inch, 1.95 * inch], small=True))

    setup_img = ROOT / "Hackathon_student" / "Hackathon_student" / "ExperimentalSetup.png"
    if setup_img.is_file():
        story.append(Spacer(1, 8))
        story.append(RLImage(str(setup_img), width=6.9 * inch, height=3.0 * inch))
        story.append(Paragraph("Figura 1. Montaje físico del beamline usado por SIMION.", styles["Small"]))

    story.append(Paragraph("5. Modelo elegido", styles["H1x"]))
    story.append(p("El modelo actual es un ensemble de redes neuronales MLP multitarea. Ensemble significa que entrenamos varias redes con semillas distintas y promediamos sus respuestas. El promedio es la predicción; el desacuerdo entre redes sirve como una estimación práctica de incertidumbre.", styles["BodyJ"]))
    story.append(p("Durante entrenamiento, los voltajes y las salidas se escalan para evitar que la red aprenda mal por diferencias de unidades. Los pesos se ajustan por backpropagation con AdamW y una pérdida log-cosh ponderada. Esta pérdida es más robusta que MSE ante puntos raros o transiciones abruptas.", styles["BodyJ"]))
    arch_table = [
        ["Componente", "Estado actual"],
        ["Arquitectura", "Ensemble de MLPs multitarea"],
        ["Capas ocultas", "128, 128, 64"],
        ["Activación", "GELU"],
        ["Regularización", "Dropout 0.03 + weight decay"],
        ["Optimizador", "AdamW"],
        ["Pérdida", "log-cosh ponderada por relevancia física"],
        ["Diferenciabilidad", "Sí; PyTorch permite gradiente respecto a pesos y voltajes"],
    ]
    story.append(make_table(arch_table, [1.7 * inch, 5.4 * inch]))

    story.append(Paragraph("5.1 Qué significa entrenar el DT", styles["H2x"]))
    story.append(p("Cada fila del dataset tiene esta forma: ocho voltajes de entrada y las métricas reales devueltas por SIMION. La red recibe los voltajes, produce métricas predichas y se compara contra las métricas reales. Esa diferencia genera una pérdida. Con backpropagation se calcula cómo debería cambiar cada peso de la red para reducir esa pérdida. Este ciclo se repite por muchas épocas.", styles["BodyJ"]))
    story.append(make_table([
        ["Paso", "Descripción"],
        ["1. Entrada", "Se normaliza el vector de voltajes."],
        ["2. Predicción", "Cada MLP estima transmisión, forward fraction, ángulos y residual de velocidad."],
        ["3. Error", "Se compara contra SIMION usando log-cosh ponderado."],
        ["4. Backpropagation", "PyTorch calcula gradientes respecto a los pesos."],
        ["5. Actualización", "AdamW modifica los pesos."],
        ["6. Ensemble", "Se repite para varias semillas; la media predice y la dispersión indica incertidumbre."],
    ], [1.35 * inch, 5.8 * inch]))

    story.append(Paragraph("5.2 Por qué ensemble y no una sola red", styles["H2x"]))
    story.append(p("El transporte iónico en este montaje no es una función perfectamente suave: pequeños cambios de voltaje pueden convertir un haz transmitido en un haz recortado por una apertura. Una sola red puede suavizar demasiado esos acantilados. El ensemble ayuda en dos sentidos: reduce varianza al promediar y permite detectar regiones donde varios modelos no están de acuerdo.", styles["BodyJ"]))

    story.append(Paragraph("5.3 Métrica de velocidad: física primero, red después", styles["H2x"]))
    story.append(p("La rapidez total de los iones resultó casi constante en las validaciones. Por eso no entrenamos una distribución completa de velocidades como caja negra. En su lugar calculamos una base física a partir de theta_mean y theta_sigma, y la red solo aprende el residual de vz_sigma. Esto reduce complejidad y mantiene una interpretación física clara.", styles["BodyJ"]))

    story.append(Paragraph("6. Datos disponibles y cobertura", styles["H1x"]))
    story.append(p(f"El dataset base actual contiene {meta['n_rows']} filas. Todas entrenan transmisión y ángulos; {meta['residual_rows']} filas contienen además información suficiente para entrenar el residual de vz_sigma.", styles["BodyJ"]))
    story.append(RLImage(str(figures["bins"]), width=6.7 * inch, height=3.4 * inch))
    story.append(Paragraph("Figura 2. Cobertura del dataset por rangos de transmisión activa.", styles["Small"]))

    story.append(Paragraph("7. Desempeño del gemelo directo", styles["H1x"]))
    story.append(p("La validación interna separa datos de entrenamiento y validación. La métrica principal se reporta como MAE: error absoluto medio. En transmisión, 0.030 significa aproximadamente 3.0 puntos porcentuales.", styles["BodyJ"]))
    story.append(make_table(tables["metrics"], [2.4 * inch, 1.6 * inch, 1.7 * inch, 1.5 * inch], small=True))
    story.append(p("La diferencia entre error global y error high-contact es importante: la región informativa del reto es donde de verdad llegan iones. Allí el modelo es más preciso que en el promedio global, porque las zonas de transición y clipping son físicamente más abruptas.", styles["BodyJ"]))

    story.append(Paragraph("8. Diseño inverso y control", styles["H1x"]))
    story.append(p("El diseño inverso usa el mismo gemelo, pero al revés. No entrenamos otra red para invertir. Congelamos los pesos y tratamos los voltajes como variables optimizables. Por gradiente buscamos voltajes cuya salida predicha se acerque a una consigna.", styles["BodyJ"]))
    story.append(p("Este punto es central para la guía del reto: el gemelo no solo debe predecir una tabla, debe servir para controlar la máquina. Por eso validamos las consignas inversas volviendo a SIMION.", styles["BodyJ"]))
    story.append(p("Ejemplo conceptual: si pedimos 70% de transmisión, theta_mean cercano a 4° y theta_sigma cercano a 2°, el algoritmo inicia desde muchas combinaciones de voltajes, evalúa el DT, calcula una pérdida de consigna y ajusta los voltajes por gradiente. Los mejores candidatos se exportan y se validan en SIMION.", styles["BodyJ"]))
    story.append(make_table(tables["inverse"], [1.0 * inch, 1.2 * inch, 1.4 * inch, 1.4 * inch, 1.4 * inch], small=True))
    story.append(p("La zona de 20--30% existe, pero el haz llega más degradado angularmente. Para reportes y demostraciones conviene distinguir entre control de transmisión y calidad del haz.", styles["BodyJ"]))

    story.append(Paragraph("8.1 Optimización de dirección", styles["H2x"]))
    story.append(p("Para dirección, el objetivo natural es maximizar transmisión y, dentro de los puntos de transmisión alta, preferir haces más paralelos. En nuestras soluciones de alta transmisión se alcanzó 100% de contacto activo con theta_mean cercano a 2° y theta_sigma del orden de 1°. Esto es el régimen que conviene usar como demostración de buen punto de operación.", styles["BodyJ"]))

    story.append(Paragraph("8.2 Consigna inversa", styles["H2x"]))
    story.append(p("Para consigna inversa, la dificultad no es encontrar el máximo, sino producir voluntariamente diferentes niveles de transmisión. Esto obliga al DT a aprender zonas medias y bajas. Las validaciones consolidadas muestran control amplio de transmisión, pero con una advertencia: a menor transmisión, la calidad angular tiende a empeorar porque muchas soluciones de baja transmisión funcionan recortando o seleccionando parte del haz.", styles["BodyJ"]))

    story.append(Paragraph("9. Aprendizaje activo y eficiencia de datos", styles["H1x"]))
    story.append(p("Además del banco grande, implementamos un modo presupuestado: el sistema recibe un número máximo de consultas a SIMION y decide dónde medir. Este modo no reinicia al pasar de 100 a 200 puntos; crece incrementalmente y toma snapshots para estimar cuántos puntos son necesarios.", styles["BodyJ"]))
    if figures.get("learning"):
        story.append(RLImage(str(figures["learning"]), width=6.7 * inch, height=3.4 * inch))
        story.append(Paragraph("Figura 3. Curva aproximada de aprendizaje: error de transmisión vs presupuesto.", styles["Small"]))
    story.append(p("La evidencia actual sugiere que cerca de 500 puntos el modelo empieza a ser funcional, mientras que 900--1000 puntos dan un umbral más defendible para predicción y consigna inversa. Esto no significa que siempre se requieran 1000 puntos: la estrategia actual explora loops orientados a fallos de consigna inversa para intentar bajar ese umbral.", styles["BodyJ"]))

    story.append(Paragraph("9.1 Dos modos de recolección actuales", styles["H2x"]))
    story.append(make_table([
        ["Modo", "Idea", "Uso recomendado"],
        ["budget_simion_loop", "Selecciona puntos por incertidumbre, cuotas de transmisión y diversidad.", "Estimar eficiencia de datos y entrenar con presupuesto cerrado."],
        ["inverse_active_loop", "Pide consignas inversas, valida los fallos en SIMION y reentrena.", "Mejorar específicamente la tarea de consigna inversa."],
    ], [1.7 * inch, 3.3 * inch, 2.2 * inch], small=True))
    story.append(p("El segundo modo es más reciente. Nació porque la rúbrica no evalúa solo predicción directa: también evalúa si el gemelo puede controlar. Por eso estamos agregando datos donde el control inverso se equivoca, no solo donde la incertidumbre genérica es alta.", styles["BodyJ"]))

    story.append(Paragraph("9.2 Qué significa eficiencia en nuestro caso", styles["H2x"]))
    story.append(p("Eficiencia no significa usar pocos puntos a cualquier costo. Significa lograr un modelo útil con el mínimo número de consultas a SIMION. En un espacio de ocho dimensiones con regiones muertas y transiciones abruptas, 100 puntos no bastan para el modelo actual; 500 puntos dan un sistema funcional; y alrededor de 900--1000 puntos el comportamiento ya es defendible. Estos valores se reportan como curva de aprendizaje, no como dogma.", styles["BodyJ"]))

    story.append(Paragraph("10. Cómo respondemos a la rúbrica del reto", styles["H1x"]))
    rubric = [
        ["Criterio", "Cómo lo aborda nuestro sistema"],
        ["C - Dirección", "Usa diseño inverso sobre el DT para maximizar transmisión y reducir dispersión angular; soluciones de 100% transmisión ya fueron validadas."],
        ["A - Exactitud", "MAE high-contact aprox. 1.5 puntos porcentuales en transmisión y ~0.12° en theta_mean/theta_sigma."],
        ["I - Consigna inversa", "Barridos validados muestran control de transmisión desde ~20% hasta 100%, con degradación angular en baja transmisión."],
        ["E - Extrapolación/honestidad", "Ensemble entrega incertidumbre; se distinguen regiones confiables de regiones abruptas o de baja calidad angular."],
        ["D - Diferenciabilidad", "El modelo PyTorch es diferenciable; se optimizan voltajes por gradiente sobre el gemelo."],
        ["F - Eficiencia de datos", "Hay loops presupuestados e incrementales para estimar el mínimo de puntos; 500 funcional, ~900--1000 recomendado."],
        ["G - Admisibilidad", "Las salidas se recortan a rangos físicos y las métricas de ángulo solo se calculan sobre impactos válidos en ventana activa."],
    ]
    story.append(make_table(rubric, [1.3 * inch, 5.9 * inch], small=True))

    story.append(Paragraph("11. Límites y confianza actual", styles["H1x"]))
    story.append(bullet([
        "Confiamos más en la región de transmisión media-alta y alta, especialmente cuando hay impactos forward en la ventana activa.",
        "La región de baja transmisión se puede controlar, pero suele implicar clipping del haz y peor ángulo; por tanto no debe venderse como una solución tan limpia como 80--100%.",
        "El modelo actual no generaliza a otra partícula, energía o geometría sin recolectar nuevos datos. En el reto esto no es problema porque esas condiciones son fijas.",
        "La incertidumbre del ensemble es útil como señal de honestidad, pero no es una garantía estadística perfecta.",
        "El loop inverso activo está en desarrollo: su objetivo es reducir el presupuesto necesario enfocándose en los fallos de consigna, no reemplazar aún al modelo base validado.",
    ], styles["BodyJ"]))

    story.append(Paragraph("11.1 Qué no estamos afirmando", styles["H2x"]))
    story.append(p("No afirmamos que la red haya aprendido toda la física interna del beamline. Afirmamos que aprendió un mapa útil entre voltajes y métricas bajo las condiciones fijas del reto. Tampoco afirmamos que la baja transmisión sea igual de buena que la alta: puede cumplir transmisión objetivo, pero con mayor ángulo y dispersión.", styles["BodyJ"]))

    story.append(Paragraph("11.2 Qué sí podemos defender", styles["H2x"]))
    story.append(bullet([
        "El flujo completo existe: SIMION -> dataset -> entrenamiento -> predicción -> diseño inverso -> validación.",
        "El modelo es diferenciable y se usa efectivamente para optimizar voltajes.",
        "Las salidas son admisibles y se calculan sobre impactos físicos válidos.",
        "El sistema distingue regiones informativas de regiones muertas o abruptas.",
        "La bitácora conserva decisiones y resultados para reproducibilidad.",
    ], styles["BodyJ"]))

    story.append(Paragraph("12. Archivos clave para el grupo", styles["H1x"]))
    files = [
        ["Archivo", "Función"],
        ["dt/dt_config.json", "configuración de voltajes, bounds, targets e hiperparámetros"],
        ["dt/train_dt.py", "entrenamiento del ensemble MLP"],
        ["dt/predict_dt.py", "predicción directa"],
        ["dt/inverse_design.py", "diseño inverso diferenciable"],
        ["dt/validate_candidates.py", "validación de candidatos en SIMION"],
        ["dt/budget_simion_loop.py", "entrenamiento autónomo con presupuesto"],
        ["dt/inverse_active_loop.py", "aprendizaje activo orientado a fallos de consigna inversa"],
        ["dt/EXPERIMENT_LOG.md", "registro de decisiones y resultados validados"],
    ]
    story.append(make_table(files, [2.4 * inch, 4.8 * inch], small=True))

    story.append(Paragraph("13. Guía práctica para el equipo", styles["H1x"]))
    story.append(p("Si alguien del grupo quiere entender o ejecutar el sistema sin entrar en todos los detalles, puede pensar en tres comandos: entrenar, predecir y validar diseño inverso. En la práctica, durante el hackathon conviene no modificar la geometría ni los PA salvo que sea estrictamente necesario; para cambiar voltajes usamos fastadj.", styles["BodyJ"]))
    story.append(make_table([
        ["Objetivo", "Comando/base"],
        ["Entrenar modelo principal", r".\.venv\Scripts\python.exe .\dt\train_dt.py"],
        ["Predecir métricas para voltajes", r".\.venv\Scripts\python.exe .\dt\predict_dt.py --voltages V3=... V6=..."],
        ["Diseño inverso", r".\.venv\Scripts\python.exe .\dt\inverse_design.py --target-active ..."],
        ["Validar candidatos en SIMION", r".\.venv\Scripts\python.exe .\dt\validate_candidates.py --top 5"],
        ["Ver bitácora", r"dt\EXPERIMENT_LOG.md"],
    ], [2.3 * inch, 4.9 * inch], small=True))

    story.append(Paragraph("14. Mensaje final", styles["H1x"]))
    story.append(p("La versión actual es un primer gemelo digital completo y defendible: no es solo un optimizador de voltajes ni solo una red que ajusta una tabla. Es un ciclo de control: aprende de SIMION, predice, propone voltajes y vuelve a validar. Para el grupo, la prioridad ahora no es cambiar toda la arquitectura, sino consolidar evidencia: figuras predicho-vs-real, curva de aprendizaje, control inverso y ejemplos claros de dónde el modelo confía y dónde no.", styles["BodyJ"]))

    doc.build(story, onFirstPage=page_footer, onLaterPages=page_footer)


def make_table(data: list[list[str]], widths: list[float], small: bool = False) -> Table:
    style = TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f4e79")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 7.5 if small else 8.4),
            ("LEADING", (0, 0), (-1, -1), 9.0 if small else 10.2),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#b8c6d1")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f5f8fb")]),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]
    )
    wrapped = []
    tiny = ParagraphStyle("tbl", fontName="Helvetica", fontSize=7.5 if small else 8.4, leading=9 if small else 10.2)
    head = ParagraphStyle("tblh", fontName="Helvetica-Bold", fontSize=7.5 if small else 8.4, leading=9 if small else 10.2, textColor=colors.white)
    for r, row in enumerate(data):
        wrapped.append([Paragraph(str(cell), head if r == 0 else tiny) for cell in row])
    t = Table(wrapped, colWidths=widths, repeatRows=1)
    t.setStyle(style)
    return t


def build_tex(tex_path: Path, meta: dict) -> None:
    text = rf"""
\documentclass[11pt]{{article}}
\usepackage[spanish]{{babel}}
\usepackage[utf8]{{inputenc}}
\usepackage[T1]{{fontenc}}
\usepackage{{geometry}}
\usepackage{{booktabs}}
\usepackage{{graphicx}}
\usepackage{{hyperref}}
\geometry{{margin=2.2cm}}
\title{{Reporte del sistema actual de Gemelo Digital SIMION}}
\author{{Versión interna para el grupo de trabajo}}
\date{{{meta['date']}}}

\begin{{document}}
\maketitle

\section{{Resumen ejecutivo}}
Construimos un gemelo digital del beamline de SIMION: un emulador que recibe ocho voltajes libres
$(V3,V6,V9,V10,V11,V12,V15,V18)$ y predice métricas del haz. El sistema actual usa un ensemble de
redes neuronales MLP diferenciables. Además de predicción directa, permite diseño inverso por gradiente:
dada una consigna de transmisión y ángulo, busca voltajes que deberían cumplirla y luego los valida en SIMION.

\section{{Entradas y salidas}}
Entradas: ocho voltajes libres del reto. Salidas principales: transmisión activa, fracción forward,
ángulo medio de impacto, dispersión angular y residual de $v_z$ sigma sobre una base física.

\section{{Arquitectura}}
El modelo es un ensemble de MLPs multitarea con capas ocultas 128--128--64, activación GELU,
dropout 0.03, AdamW y pérdida log-cosh ponderada. Las entradas y salidas se escalan antes del entrenamiento.

\section{{Datos y desempeño}}
Dataset base: {meta['n_rows']} filas. Filas con residual de velocidad observado: {meta['residual_rows']}.
MAE global de transmisión: {100*meta['mae_contact']:.2f} puntos porcentuales. MAE high-contact:
{100*meta['mae_contact_high']:.2f} puntos porcentuales. MAE high-contact de theta mean:
{meta['mae_theta_high']:.3f} grados. MAE high-contact de theta sigma: {meta['mae_sigma_high']:.3f} grados.

\section{{Control inverso}}
El diseño inverso congela la red y optimiza los voltajes de entrada por backpropagation. Los barridos
validados muestran control de transmisión aproximadamente desde 20\% hasta 100\%, con degradación angular
en baja transmisión.

\section{{Rúbrica del reto}}
\begin{{itemize}}
\item C, dirección: soluciones de alta transmisión validadas.
\item A, exactitud: error bajo en región informativa high-contact.
\item I, consigna inversa: barridos inversos validados en SIMION.
\item E, honestidad: incertidumbre por ensemble y distinción de regiones confiables/no confiables.
\item D, diferenciabilidad: modelo PyTorch diferenciable.
\item F, eficiencia: loops presupuestados para estimar número mínimo de evaluaciones.
\item G, admisibilidad: salidas físicas recortadas y métricas calculadas sobre impactos válidos.
\end{{itemize}}

\section{{Archivos clave}}
\begin{{itemize}}
\item \texttt{{dt/train\_dt.py}}: entrenamiento.
\item \texttt{{dt/predict\_dt.py}}: predicción directa.
\item \texttt{{dt/inverse\_design.py}}: diseño inverso.
\item \texttt{{dt/budget\_simion\_loop.py}}: entrenamiento autónomo con presupuesto.
\item \texttt{{dt/inverse\_active\_loop.py}}: aprendizaje activo por fallos de consigna.
\item \texttt{{dt/EXPERIMENT\_LOG.md}}: bitácora técnica.
\end{{itemize}}

\end{{document}}
"""
    tex_path.write_text(dedent(text).strip() + "\n", encoding="utf-8")


def main() -> None:
    summary = load_json(ROOT / "dt" / "models" / "baseline_mlp" / "training_summary.json")
    bin_report = summary["bin_report"]
    bins = [(row["bin"].replace("0.98-1.00", "98-100%").replace("0.80-0.98", "80-98%"), float(row["count"])) for row in bin_report]
    bins_png = OUT / "fig_dataset_bins.png"
    make_bar_chart(bins, "Cobertura del dataset por transmisión", bins_png)

    learning_csv = ROOT / "dt" / "models" / "budget_benchmark_1500" / "summary.csv"
    learning_png = OUT / "fig_learning_curve.png"
    learning_series = []
    for row in read_csv(learning_csv):
        try:
            learning_series.append((int(float(row["budget"])), float(row["contact_global_mae"])))
        except Exception:
            pass
    if learning_series:
        make_line_chart(learning_series, "Error de transmisión vs presupuesto", learning_png, "MAE")

    targets = summary["target_names"]
    metrics_rows = [["Métrica", "MAE global", "MAE high-contact", "Interpretación"]]
    labels = {
        "detector_active_contact_fraction": ("Transmisión activa", "fracción; 0.03 = 3 pp"),
        "detector_active_forward_fraction": ("Forward fraction", "fracción direccional"),
        "detector_contact_angle_theta_mean_deg": ("theta_mean", "grados"),
        "detector_contact_angle_theta_sigma_deg": ("theta_sigma", "grados"),
        "derived_vz_sigma_residual": ("vz_sigma residual", "corrección sobre física base"),
    }
    for key in targets:
        name, interp = labels.get(key, (key, ""))
        metrics_rows.append([
            name,
            fmt(avg_metric(summary, "mae", key), 4),
            fmt(avg_metric(summary, "high_contact_mae", key), 4),
            interp,
        ])

    inverse_rows = [
        ["Objetivo", "SIMION", "theta_mu", "theta_sigma", "Comentario"],
        ["20%", "19.0%", "9.237°", "6.189°", "baja transmisión, calidad angular degradada"],
        ["30%", "30.4%", "5.651°", "2.739°", "familia baja viable"],
        ["40%", "40.6%", "5.556°", "2.922°", "control razonable"],
        ["50%", "50.4%", "5.048°", "2.494°", "control medio estable"],
        ["70%", "69.6%", "4.770°", "2.291°", "zona media-alta"],
        ["90%", "91.4%", "3.554°", "1.589°", "alta transmisión"],
        ["100%", "100.0%", "2.301°", "1.148°", "óptimo práctico"],
    ]

    meta = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "n_rows": summary["n_rows"],
        "residual_rows": summary["target_observed_count"].get("derived_vz_sigma_residual", 0),
        "mae_contact": avg_metric(summary, "mae", "detector_active_contact_fraction") or 0,
        "mae_contact_high": avg_metric(summary, "high_contact_mae", "detector_active_contact_fraction") or 0,
        "mae_theta_high": avg_metric(summary, "high_contact_mae", "detector_contact_angle_theta_mean_deg") or 0,
        "mae_sigma_high": avg_metric(summary, "high_contact_mae", "detector_contact_angle_theta_sigma_deg") or 0,
    }
    tex_path = OUT / "reporte_sistema_actual_dt.tex"
    pdf_path = OUT / "reporte_sistema_actual_dt.pdf"
    build_tex(tex_path, meta)
    build_pdf(
        pdf_path,
        {"bins": bins_png, "learning": learning_png if learning_series else None},
        {"metrics": metrics_rows, "inverse": inverse_rows},
        meta,
    )
    print(f"TEX: {tex_path}")
    print(f"PDF: {pdf_path}")


if __name__ == "__main__":
    main()
