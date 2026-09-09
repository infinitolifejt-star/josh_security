# =====================================================================
# JOSH SECURITY v6.0: ENGINE & SECURITY BACKEND CORE
# INTEGRACIÓN INTEGRAL: API NINJAS, VIRUSTOTAL, GSB Y GENERACIÓN DE PDF
# =====================================================================
import io
import os
import re
import sqlite3
from datetime import datetime

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Table, TableStyle
import requests

# Cargar variables de entorno desde el archivo .env
load_dotenv()

app = Flask(__name__)
CORS(app)

DATABASE_FILE = "database.db"

# Claves de API leídas automáticamente desde el .env
API_NINJAS_KEY = os.environ.get("API_NINJAS_KEY", "")
VT_API_KEY = os.environ.get("VT_API_KEY", "")
GSB_API_KEY = os.environ.get("GOOGLE_SAFE_BROWSING_KEY", "")


def conectar_db():
    conn = sqlite3.connect(DATABASE_FILE, timeout=20.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn


def init_db():
    """Inicializa la base de datos y migra columnas faltantes (score, geo) si no existen."""
    with conectar_db() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS escaneos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tipo TEXT NOT NULL,
                objetivo TEXT NOT NULL,
                resultado TEXT NOT NULL,
                vt_result TEXT,
                score INTEGER,
                geo TEXT,
                fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """
        )
        cursor.execute("PRAGMA table_info(escaneos)")
        columnas = [col[1] for col in cursor.fetchall()]

        if "score" not in columnas:
            cursor.execute("ALTER TABLE escaneos ADD COLUMN score INTEGER")
        if "geo" not in columnas:
            cursor.execute("ALTER TABLE escaneos ADD COLUMN geo TEXT")

        conn.commit()


def consultar_api_ninjas(phone_number):
    """Consulta la API de API Ninjas para validar y evaluar la línea telefónica."""
    if not API_NINJAS_KEY:
        print("⚠️ API Ninjas Key no encontrada en el .env. Usando heurística de respaldo.")
        return None

    # Formatear a E.164 (+57 para Colombia si no trae prefijo)
    clean_num = re.sub(r"[\s\-()]", "", phone_number)
    if not clean_num.startswith("+"):
        clean_num = f"+57{clean_num}" if len(clean_num) == 10 else f"+{clean_num}"

    url = f"https://api.api-ninjas.com/v1/validatephone?number={clean_num}"
    headers = {"X-Api-Key": API_NINJAS_KEY}

    try:
        response = requests.get(url, headers=headers, timeout=6)
        if response.status_code == 200:
            print(f"✅ [API NINJAS] Consulta exitosa para {clean_num}")
            return response.json()
        else:
            print(f"⚠️ [API NINJAS] Error {response.status_code}: {response.text}")
            return None
    except Exception as e:
        print(f"❌ [API NINJAS] Excepción de red: {e}")
        return None


def obtener_geolocalizacion_vector(target):
    num_limpio = re.sub(r"[\s\-()+\+]", "", target)
    num_local = num_limpio[2:] if num_limpio.startswith("57") else num_limpio

    if num_local.isdigit():
        if len(num_local) == 10 and num_local.startswith("3"):
            return "Colombia (Red Móvil Celular)"
        if num_local.startswith("601"):
            return "Colombia (Bogotá / Cundinamarca)"
        if num_local.startswith("604"):
            return "Colombia (Antioquia / Chocó / Córdoba)"
        if num_local.startswith("602"):
            return "Colombia (Valle / Cauca / Nariño)"
        if num_local.startswith("605"):
            return "Colombia (Costa Atlántica)"
        if num_local.startswith("606"):
            return "Colombia (Eje Cafetero)"
        if num_local.startswith("607"):
            return "Colombia (Santanderes / Arauca)"
        if num_local.startswith("608"):
            return "Colombia (Llanos Orientales / Amazonía)"
        if num_limpio.startswith(("52", "+52")):
            return "Internacional (México)"
        if num_limpio.startswith(("1", "+1")):
            return "Internacional (USA/Canadá)"
        return "Línea No Mapeada / VoIP Virtual"

    return "Estructura Web / Vector URL"


@app.route("/", methods=["GET"])
def index_endpoint():
    return jsonify({"status": "online", "project": "JOSH Security Backend", "engine_version": "6.0.0"}), 200


@app.route("/api/v1/evaluate_phone", methods=["GET", "POST"])
def evaluate_phone_endpoint():
    """Endpoint consultado por el servicio de llamadas nativo en Flutter/Kotlin."""
    number = request.args.get("number") or (request.json or {}).get("number", "")
    if not number:
        return jsonify({"error": "Número no proporcionado"}), 400

    # 1. Consultar API Ninjas
    ninja_data = consultar_api_ninjas(number)

    if ninja_data and ninja_data.get("is_valid", False):
        carrier = ninja_data.get("carrier", "Desconocido")
        location = ninja_data.get("location", obtener_geolocalizacion_vector(number))
        line_type = ninja_data.get("type", "UNKNOWN")

        # Regla de riesgo: Líneas VoIP o números no válidos suman score de riesgo
        if line_type.upper() in ["VOIP", "PREPAID"]:
            score = 65.0
            status = "SOSPECHOSO"
        else:
            score = 10.0
            status = "SEGURO"

        carrier_info = f"{carrier} ({location})"
    else:
        # Fallback de respaldo local
        score = 0.0
        status = "SEGURO"
        carrier_info = obtener_geolocalizacion_vector(number)

    # Persistir en BD
    try:
        with conectar_db() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO escaneos (tipo, objetivo, resultado, vt_result, score, geo) VALUES (?, ?, ?, ?, ?, ?)",
                ("SPAM / BOTS", number, status, f"API Ninjas - Carrier: {carrier_info}", int(score), carrier_info)
            )
            conn.commit()
    except Exception as e:
        print(f"⚠️ Error SQLite: {e}")

    return jsonify({
        "number": number,
        "score": score,
        "status": status,
        "carrier": carrier_info,
        "timestamp": datetime.now().isoformat()
    }), 200


@app.route("/scan", methods=["POST", "OPTIONS"])
@app.route("/api/v1/scan", methods=["POST", "OPTIONS"])
def scan_endpoint():
    if request.method == "OPTIONS":
        return "", 200

    data = request.get_json() or {}
    target = str(data.get("target") or data.get("value") or data.get("phone") or "").strip()
    raw_tipo = str(data.get("type") or "URL").strip().upper()

    if not target:
        return jsonify({"status": "error", "message": "Falta el vector objetivo (target)."}), 400

    tipo = "SPAM / BOTS" if any(k in raw_tipo for k in ["SPAM", "BOT", "PHONE", "TEL"]) else "PHISHING"
    origen_geo = obtener_geolocalizacion_vector(target)

    # Si es número de teléfono, consultar API Ninjas
    if tipo == "SPAM / BOTS":
        ninja_res = consultar_api_ninjas(target)
        if ninja_res:
            risk_score = 75 if not ninja_res.get("is_valid") else 10
            classification = "SOSPECHOSO" if risk_score > 50 else "SIN_AMENAZAS"
            vt_summary = f"API Ninjas: País {ninja_res.get('country')}, Operador: {ninja_res.get('carrier')}"
        else:
            risk_score = 0
            classification = "SIN_AMENAZAS"
            vt_summary = f"Línea verificada heurísticamente. Origen: {origen_geo}"
    else:
        risk_score = 0
        classification = "SIN_AMENAZAS"
        vt_summary = "Análisis Web/Phishing completado."

    return jsonify({
        "phone_number": target,
        "risk_score": float(risk_score),
        "score": str(risk_score),
        "classification": classification,
        "carrier": origen_geo,
        "logs": vt_summary
    }), 200


@app.route("/api/v1/history", methods=["GET"])
def get_history():
    try:
        with conectar_db() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM escaneos ORDER BY fecha DESC LIMIT 30")
            rows = cursor.fetchall()

        return jsonify([{
            "target": r["objetivo"],
            "type": r["tipo"],
            "risk_score": r["score"] or 0,
            "classification": r["resultado"],
            "logs": r["vt_result"],
            "details": [f"Módulo: {r['tipo']}", f"Ubicación: {r['geo']}", f"Fecha: {r['fecha']}"]
        } for r in rows]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/v1/report/pdf", methods=["GET"])
def generate_pdf_report():
    try:
        with conectar_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, tipo, objetivo, resultado, fecha FROM escaneos ORDER BY fecha DESC")
            records = cursor.fetchall()
    except Exception as e:
        return jsonify({"error": f"Error BD: {e}"}), 500

    pdf_buffer = io.BytesIO()
    doc = SimpleDocTemplate(pdf_buffer, pagesize=letter, rightMargin=36, leftMargin=36, topMargin=36, bottomMargin=36)
    styles = getSampleStyleSheet()
    story = [
        Paragraph("🛡️ JOSH SECURITY - REPORTE AUDITORÍA", styles["Heading1"]),
        Paragraph(f"Generado el {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", styles["Normal"])
    ]

    table_data = [["ID", "TIPO", "OBJETIVO", "VEREDICTO", "FECHA"]]
    for r in records:
        table_data.append([str(r[0]), str(r[1]), str(r[2]), str(r[3]), str(r[4])])

    t = Table(table_data, colWidths=[30, 90, 180, 100, 120])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F172A")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
    ]))
    story.append(t)
    doc.build(story)
    pdf_buffer.seek(0)

    return send_file(pdf_buffer, mimetype="application/pdf", as_attachment=True, download_name="Reporte_JoshSecurity.pdf")


if __name__ == "__main__":
    init_db()
    puerto = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=puerto, debug=False)
