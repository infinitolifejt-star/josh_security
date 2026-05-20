import os
import requests
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# ==========================================
# CONFIGURACIÓN DE CREDENCIALES (BACKEND)
# ==========================================
# Pega tu API Key de VirusTotal aquí adentro de las comillas
VIRUSTOTAL_API_KEY = "TU_CLAVE_DE_VIRUSTOTAL_AQUI"

SCAN_HISTORY = [
    {
        "id": 1,
        "fileName": "registro_firewall.sys",
        "verdict": "SEGURO",
        "engine": "Gateway Global Centinela v1"
    }
]

@app.route('/api/history', methods=['GET'])
def get_history():
    return jsonify(SCAN_HISTORY), 200

@app.route('/api/v1/scan', methods=['POST'])
def scan_file():
    data = request.get_json() or {}
    file_name = data.get("fileName", "archivo_desconocido")
    
    new_report = {
        "id": len(SCAN_HISTORY) + 1,
        "fileName": file_name,
        "verdict": "SEGURO",
        "engine": "Motor Forense Global Centinela (Python Backend)",
    }
    
    SCAN_HISTORY.insert(0, new_report)
    return jsonify({"status": "SUCCESS", "data": new_report}), 200

@app.route('/api/v1/scan-url', methods=['POST'])
def scan_url():
    """ Enrutador táctico seguro para consultar dominios en VirusTotal """
    data = request.get_json() or {}
    url_to_scan = data.get("url", "")
    
    if not url_to_scan:
        return jsonify({"status": "ERROR", "message": "Falta la URL"}), 400

    # Si aún no has pegado tu clave real, devolvemos simulación limpia
    if VIRUSTOTAL_API_KEY == "TU_CLAVE_DE_VIRUSTOTAL_AQUI":
        mock_report = {
            "url": url_to_scan,
            "verdict": "SEGURO",
            "engine": "Simulador Interno Centinela (Falta API Key)"
        }
        return jsonify({"status": "SUCCESS", "data": mock_report}), 200

    # Llamada real y protegida a la API oficial de VirusTotal v3
    try:
        vt_url = "https://www.virustotal.com/api/v3/urls"
        payload = {"url": url_to_scan}
        headers = {
            "accept": "application/json",
            "x-apikey": VIRUSTOTAL_API_KEY,
            "content-type": "application/x-www-form-urlencoded"
        }
        
        response = requests.post(vt_url, data=payload, headers=headers)
        if response.statusCode == 200:
            return jsonify({"status": "SUCCESS", "message": "URL enviada a análisis con éxito", "vt_data": response.json()}), 200
        else:
            return jsonify({"status": "ERROR", "message": f"Error de VT: {response.status_code}"}), response.status_code
            
    except Exception as e:
        return jsonify({"status": "ERROR", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, debug=True)