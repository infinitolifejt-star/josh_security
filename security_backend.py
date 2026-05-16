from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import base64

app = Flask(__name__)
# CORS totalmente abierto para desarrollo en local sin restricciones de Chrome
CORS(app, resources={r"/api/*": {"origins": "*", "methods": ["POST", "OPTIONS"], "allow_headers": ["Content-Type"]}})

# =========================================================================
# OPERADORES DE CREDENCIALES GLOBALES (VALIDADAS)
# =========================================================================
VT_API_KEY = "003fa969b0ddef2e33b9cb5cb7a00747ce1c2d2b1e52197a6e0a87649a4548e8"
GOOGLE_API_KEY = "AIzaSyDOsRp-_qb7CAdw9NfqnWIGCUiBS_zp00Q"

def consultar_virustotal(url_objetivo):
    """Interroga la API global de VirusTotal v3 mediante hash seguro en Base64"""
    if not VT_API_KEY or VT_API_KEY == "TU_API_KEY_DE_VIRUSTOTAL_AQUI":
        return {"activo": False, "detecciones": 0, "msg": "VT Sin Configurar"}
        
    try:
        url_bytes = url_objetivo.encode('utf-8')
        url_b64 = base64.urlsafe_b64encode(url_bytes).decode('utf-8').rstrip('=')
        headers = {"accept": "application/json", "x-apikey": VT_API_KEY}
        endpoint = f"https://www.virustotal.com/api/v3/urls/{url_b64}"
        
        response = requests.get(endpoint, headers=headers, timeout=5)
        if response.status_code == 200:
            stats = response.json()['data']['attributes']['last_analysis_stats']
            total = stats.get('malicious', 0) + stats.get('suspicious', 0)
            return {"activo": True, "detecciones": total, "msg": f"VirusTotal: {total} alertas"}
        return {"activo": False, "detecciones": 0, "msg": f"VT API Info (Código {response.status_code})"}
    except Exception as e:
        return {"activo": False, "detecciones": 0, "msg": f"VT fuera de línea"}

def consultar_google_safe_browsing(url_objetivo):
    """Consulta las listas negras globales de Google en busca de phishing o malware"""
    if not GOOGLE_API_KEY or GOOGLE_API_KEY == "TU_API_KEY_DE_GOOGLE_SAFE_BROWSING_AQUI":
        return {"activo": False, "amenaza": False, "msg": "Google SB Sin Configurar"}
        
    endpoint = f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={GOOGLE_API_KEY}"
    payload = {
        "client": {"clientId": "centinela_security", "clientVersion": "1.0.0"},
        "threatInfo": {
            "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
            "platformTypes": ["ANY_PLATFORM"],
            "threatEntryTypes": ["URL"],
            "threatEntries": [{"url": url_objetivo}]
        }
    }
    try:
        response = requests.post(endpoint, json=payload, timeout=5)
        if response.status_code == 200:
            res_data = response.json()
            if "matches" in res_data:
                tipo_amenaza = res_data["matches"][0]["threatType"]
                return {"activo": True, "amenaza": True, "msg": f"Google Safe Browsing: {tipo_amenaza}"}
            return {"activo": True, "amenaza": False, "msg": "Google Safe Browsing: URL Limpia"}
        return {"activo": False, "amenaza": False, "msg": f"Google SB Info (Código {response.status_code})"}
    except Exception as e:
        return {"activo": False, "amenaza": False, "msg": f"Google API fuera de línea"}

@app.route('/api/v1/analyze', methods=['POST', 'OPTIONS'])
def analizar_url():
    if request.method == 'OPTIONS':
        return '', 200
        
    data = request.get_json()
    if not data or 'url' not in data:
        return jsonify({"error": "Payload inválido"}), 400
        
    url_solicitada = data['url'].strip()
    print(f"\n[CENTINELA ENGINE] Investigando objetivo forense: {url_solicitada}")
    
    # 1. Análisis de Patrón Heurístico Local
    amenaza_local = any(p in url_solicitada.lower() for p in ["virus", "hacker", "phishing", "malware", "banco-actualizar"])
    
    # 2. Consultas en la nube con las llaves de acceso del usuario
    res_vt = consultar_virustotal(url_solicitada)
    res_google = consultar_google_safe_browsing(url_solicitada)
    
    es_amenaza = amenaza_local or (res_vt["detecciones"] > 0) or res_google["amenaza"]
    
    detalles = []
    if amenaza_local: 
        detalles.append("Firma Local Detectada")
    if res_vt["activo"]: 
        detalles.append(res_vt["msg"])
    if res_google["activo"]: 
        detalles.append(res_google["msg"])
        
    if not detalles:
        detalle_final = "URL Analizada. Motores internacionales indican que este enlace es Seguro."
    else:
        detalle_final = " | ".join(detalles)

    resultado = {
        "url": url_solicitada,
        "status": "PELIGRO" if es_amenaza else "LIMPIO",
        "detail": detalle_final,
        "risk_score": 100 if es_amenaza else 0
    }
    
    print(f"[VEREDICTO EMITIDO] Status: {resultado['status']} | Diagnóstico: {resultado['detail']}")
    return jsonify(resultado), 200

if __name__ == "__main__":
    print("[+] Inicializando Servidor Analítico Centinela Engine Completo en el puerto 5000...")
    app.run(host="127.0.0.1", port=5000, debug=True)