import hashlib
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os

# Cargar variables de entorno del archivo .env
load_dotenv()
VT_API_KEY = os.getenv("VIRUSTOTAL_API_KEY")

app = Flask(__name__)
# Habilitar CORS para permitir que la app de Flutter Web se comunique sin bloqueos
CORS(app)

def process_vt_stats(stats):
    """Calcula el veredicto basado en las estadísticas de VirusTotal."""
    malicious = stats.get("malicious", 0)
    suspicious = stats.get("suspicious", 0)
    harmless = stats.get("harmless", 0)
    undetected = stats.get("undetected", 0)
    
    total_clean = harmless + undetected

    if malicious > 3:
        status = "danger"
        message = f"¡ALERTA CRÍTICA! Este vector ha sido reportado como MALICIOSO por {malicious} motores de seguridad globales."
    elif malicious > 0 or suspicious > 1:
        status = "warning"
        message = f"ADVERTENCIA DE SEGURIDAD: El vector presenta comportamientos sospechosos ({malicious} maliciosos, {suspicious} sospechosos)."
    else:
        status = "safe"
        message = f"Análisis completado de forma exitosa. El vector se encuentra LIMPIO y seguro para su interacción."

    return {
        "status": status,
        "message": message,
        "malicious": malicious,
        "suspicious": suspicious,
        "harmless": total_clean
    }

# --- RUTA 1: ANÁLISIS DE URLS ---
@app.route('/api/analyze-url', methods=['POST'])
def analyze_url():
    data = request.get_json()
    if not data or 'url' not in data:
        return jsonify({"error": "Falta el parámetro 'url' en la solicitud táctica."}), 400

    target_url = data['url']
    headers = {"x-apikey": VT_API_KEY}
    
    try:
        # Generar el ID de URL requerido por la API de VirusTotal v3
        url_id = hashlib.sha256(target_url.encode()).hexdigest()
        vt_url = f"https://www.virustotal.com/api/v3/urls/{url_id}"
        
        response = requests.get(vt_url, headers=headers)
        
        if response.status_code == 200:
            vt_data = response.json()
            stats = vt_data["data"]["attributes"]["last_analysis_stats"]
            result = process_vt_stats(stats)
            return jsonify(result)
            
        elif response.status_code == 404:
            # Si no existe en los registros, solicitamos un análisis nuevo rápido
            scan_url = "https://www.virustotal.com/api/v3/urls"
            scan_response = requests.post(scan_url, headers=headers, data={"url": target_url})
            
            if scan_response.status_code == 200:
                return jsonify({
                    "status": "safe",
                    "message": "El enlace ha sido enviado a la cola de rastreo global. No registra firmas previas de peligro.",
                    "malicious": 0,
                    "suspicious": 0,
                    "harmless": 0
                })
            
        return jsonify({"error": f"Error en la central analítica global: {response.status_code}"}), response.status_code

    except Exception as e:
        return jsonify({"error": f"Falla interna en el script del servidor: {str(e)}"}), 500


# --- RUTA 2: ANÁLISIS FORENSE DE ARCHIVOS (NUEVO) ---
@app.route('/api/analyze-file', methods=['POST'])
def analyze_file():
    if 'file' not in request.files:
        return jsonify({"error": "No se detectó ningún archivo en el canal de transmisión."}), 400
        
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Nombre de archivo no válido o vacío."}), 400

    headers = {"x-apikey": VT_API_KEY}
    
    try:
        # Calcular el Hash SHA-256 del archivo cargado (método forense rápido sin consumir cuotas pesadas)
        sha256_hash = hashlib.sha256()
        file_bytes = file.read()
        sha256_hash.update(file_bytes)
        file_id = sha256_hash.hexdigest()
        
        # Consultar si el Hash ya ha sido analizado previamente a nivel mundial
        vt_url = f"https://www.virustotal.com/api/v3/files/{file_id}"
        response = requests.get(vt_url, headers=headers)
        
        if response.status_code == 200:
            vt_data = response.json()
            stats = vt_data["data"]["attributes"]["last_analysis_stats"]
            result = process_vt_stats(stats)
            # Agregar el hash al resultado para la auditoría de Flutter
            result["hash"] = file_id
            return jsonify(result)
            
        elif response.status_code == 404:
            # El archivo nunca ha sido visto por VirusTotal, está limpio o es privado/único
            return jsonify({
                "status": "safe",
                "message": f"Análisis Hash: {file_id[:16]}... El archivo no posee firmas registradas en la base de datos global de malware. Se presume íntegro.",
                "malicious": 0,
                "suspicious": 0,
                "harmless": 1,
                "hash": file_id
            })
            
        return jsonify({"error": f"Error de comunicación con la base de datos: {response.status_code}"}), response.status_code

    except Exception as e:
        return jsonify({"error": f"Error en el procesamiento forense: {str(e)}"}), 500

if __name__ == '__main__':
    # Ejecutar en el puerto 5000 para el puente táctico
    app.run(host='0.0.0.0', port=5000, debug=True)