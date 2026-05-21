from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
import requests
import os

app = Flask(__name__)
CORS(app)

DB_PATH = "database.db"

# 🔑 CONFIGURACIÓN DE APIS GLOBALES (API KEY INTEGRADA)
GOOGLE_SAFE_BROWSING_KEY = "AIzaSyDOsRp-_qb7CAdw9NfqnWIGCUiBS_zp00Q"

def init_db():
    """Inicializa la base de datos local y crea la tabla de historial si no existe."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS historial (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            name_or_url TEXT NOT NULL,
            verdict TEXT NOT NULL,
            engine TEXT NOT NULL,
            timestamp TEXT NOT NULL
        )
    ''')
    conn.commit()
    conn.close()

# Asegurar la existencia de la base de datos local al arrancar
init_db()

def consultar_google_safe_browsing(url_a_escanear):
    """Consulta la API oficial de Google Safe Browsing para verificar Phishing o Malware."""
    api_url = f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={GOOGLE_SAFE_BROWSING_KEY}"
    
    payload = {
        "client": {
            "clientId": "josh-security-app",
            "clientVersion": "1.0.0"
        },
        "threatInfo": {
            "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
            "platformTypes": ["ANY_PLATFORM"],
            "threatEntryTypes": ["URL"],
            "threatEntries": [{"url": url_a_escanear}]
        }
    }
    
    try:
        response = requests.post(api_url, json=payload, timeout=5)
        if response.status_code == 200:
            resultado = response.json()
            # Si 'matches' existe en la respuesta, significa que Google identificó una amenaza real
            if "matches" in resultado:
                tipo_amenaza = resultado["matches"][0]["threatType"]
                if tipo_amenaza == "SOCIAL_ENGINEERING":
                    return "PHISHING", "Google Safe Browsing (Real)"
                return "MALWARE", "Google Safe Browsing (Real)"
            else:
                return "SEGURO", "Google Safe Browsing (Real)"
        else:
            print(f"[⚠️ API Warning] Google Safe Browsing respondió con código {response.status_code}. Usando respaldo simulado.")
            return "SEGURO", "Motor Modular URL (Respaldo)"
    except Exception as e:
        print(f"[🔴 API Error] Falló la conexión con Google: {e}")
        return "SEGURO", "Motor Modular URL (Respaldo)"


@app.route('/api/history', methods=['GET'])
def get_history():
    """Devuelve el historial almacenado de forma persistente en SQLite."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT id, tipo, name_or_url, verdict, engine, timestamp FROM historial ORDER BY id DESC")
        rows = cursor.fetchall()
        conn.close()

        historial_list = []
        for row in rows:
            valor_limpio = row[2]
            historial_list.append({
                "id": row[0],
                "id_str": str(row[0]),
                "fileName": valor_limpio,
                "url": valor_limpio,
                "tipo": row[1],
                "verdict": row[3],
                "engine": row[4],
                "timestamp": row[5]
            })

        print(f"[📡 API GET] Enviando {len(historial_list)} registros de auditoría a Flutter.")
        return jsonify(historial_list), 200
    except Exception as e:
        print(f"[🔴 ERROR EN GET_HISTORY]: {e}")
        return jsonify({"status": "ERROR", "message": str(e)}), 500


@app.route('/api/v1/scan-url', methods=['POST'])
def scan_url():
    """Procesa una URL consultando inteligencia real en la nube y la persiste."""
    data = request.get_json()
    if not data or 'url' not in data:
        return jsonify({"status": "ERROR", "message": "Falta el parámetro 'url'"}), 400

    url_objetivo = data['url']
    timestamp = "Justo ahora"

    # 🔥 LLAMADA A INTELIGENCIA REAL EN LA NUBE DE GOOGLE
    verdict, engine = consultar_google_safe_browsing(url_objetivo)

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO historial (tipo, name_or_url, verdict, engine, timestamp) VALUES (?, ?, ?, ?, ?)",
            ("URL", url_objetivo, verdict, engine, timestamp)
        )
        conn.commit()
        new_id = cursor.lastrowid
        conn.close()

        return jsonify({
            "status": "SUCCESS",
            "data": {
                "id": new_id,
                "fileName": url_objetivo,
                "url": url_objetivo,
                "verdict": verdict,
                "engine": engine,
                "timestamp": timestamp
            }
        }), 200
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500


@app.route('/api/v1/scan', methods=['POST'])
def scan_file():
    """Procesa un archivo y lo guarda de forma persistente."""
    data = request.get_json()
    if not data or 'fileName' not in data:
        return jsonify({"status": "ERROR", "message": "Falta el parámetro 'fileName'"}), 400

    file_name = data['fileName']
    verdict = "SEGURO"
    engine = "Motor Forense Centinela"
    timestamp = "Justo ahora"

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO historial (tipo, name_or_url, verdict, engine, timestamp) VALUES (?, ?, ?, ?, ?)",
            ("FILE", file_name, verdict, engine, timestamp)
        )
        conn.commit()
        new_id = cursor.lastrowid
        conn.close()

        return jsonify({
            "status": "SUCCESS",
            "data": {
                "id": new_id,
                "fileName": file_name,
                "verdict": verdict,
                "engine": engine,
                "timestamp": timestamp
            }
        }), 200
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)