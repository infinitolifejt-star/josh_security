import requests
import json

def ejecutar_diagnostico_malware():
    print("=" * 70)
    print("🧪 QA AUTOMATION - INICIANDO SIMULACIÓN DE ESCANEO DE MALWARE")
    print("=" * 70)

    url_endpoint = "http://127.0.0.1:5000/api/v1/scan"
    
    # Simulamos un payload que representa un archivo ejecutable sospechoso
    # El backend le calculará el hash SHA-256 de forma automática
    payload = {
        "type": "file",
        "target": "ransomware_test_sample.exe"
    }
    
    headers = {
        "Content-Type": "application/json"
    }

    print(f"📡 Enviando solicitud POST a: {url_endpoint}")
    print(f"📦 Payload de Inyección: {json.dumps(payload, indent=4)}")
    print("-" * 70)

    try:
        response = requests.post(url_endpoint, data=json.dumps(payload), headers=headers, timeout=12)
        
        print(f"📥 Código de Respuesta del Servidor: {response.status_code}")
        print("📊 Resultado Forense Devuelto:")
        print(json.dumps(response.json(), indent=4, ensure_ascii=False))
        
    except Exception as e:
        print(f"❌ Error crítico en la conexión de pruebas: {str(e)}")

    print("=" * 70)
    print("[🎉] PRUEBA FINALIZADA - Revisa tu interfaz de Flutter y presiona Sincronizar.")
    print("=" * 70)

if __name__ == '__main__':
    ejecutar_diagnostico_malware()