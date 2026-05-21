import requests
import sys

BASE_URL = "http://localhost:5000"

def ejecutar_diagnostico():
    print("=" * 70)
    print("🚀 SISTEMA GLOBAL CENTINELA - ENTORNO DE PRUEBAS DE PAYLOADS")
    print("=" * 70)

    # 1. Verificar si el servidor local está respondiendo en el puerto 5000
    print("[*] Verificando estado del servidor Flask...")
    try:
        check = requests.get(f"{BASE_URL}/api/history", timeout=3)
        if check.status_code == 200:
            print("[🟢] SERVIDOR ACTIVO: Puerto 5000 respondiendo correctamente.\n")
    except requests.exceptions.ConnectionError:
        print("[🔴] ERROR CRÍTICO de conexión.")
        print("    Detalle: El puerto 5000 está cerrado.")
        print("    Solución: Asegúrate de ejecutar 'python security_backend.py' en otra terminal.")
        print("=" * 70)
        sys.exit(1)

    # 2. Test del Módulo de Reputación URL Antiphishing (URL DE PRUEBA REAL DE GOOGLE)
    print("[*] Inyectando Payload de Phishing verificado por Google...")
    url_payload = {"url": "http://testsafebrowsing.appspot.com/s/phishing.html"}
    try:
        response_url = requests.post(f"{BASE_URL}/api/v1/scan-url", json=url_payload)
        print(f"    -> Código de Estado HTTP: {response_url.status_code}")
        print(f"    -> Respuesta Servidor: {response_url.text}")
    except Exception as e:
        print(f"    -> [🔴] Excepción en transferencia URL: {e}")

    print("-" * 70)

    # 3. Test del Módulo Antimalware de Archivos
    print("[*] Inyectando Payload en analizador de Archivos...")
    file_payload = {"fileName": "ransomware_test_payload.exe", "size": 2048500}
    try:
        response_file = requests.post(f"{BASE_URL}/api/v1/scan", json=file_payload)
        print(f"    -> Código de Estado HTTP: {response_file.status_code}")
        print(f"    -> Respuesta Servidor: {response_file.text}")
    except Exception as e:
        print(f"    -> [🔴] Excepción en transferencia Archivo: {e}")
        
    print("=" * 70)
    print("[🎉] PRUEBA FINALIZADA - Revisa tu interfaz de Flutter y presiona Sincronizar.")
    print("=" * 70)

if __name__ == "__main__":
    ejecutar_diagnostico()