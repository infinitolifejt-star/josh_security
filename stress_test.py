import threading
import requests
import random
import time
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuración del ecosistema local / Render
BASE_URL = "http://127.0.0.1:5000/api/v1/scan"
MAX_WORKERS = 15  # Controla la carga concurrente para evitar saturar el socket

# Bancos de datos de simulación maliciosa (Ráfagas)
TELEFONOS_ATAQUE = [
    "123456789", "111111111", "234567890", "+573001234567", 
    "4470123456", "791234567", "1800999999", "3158888888"
]

URLS_PHISHING = [
    "https://banco-falso-login.com", "https://actualiza-tus-datos-aqui.net",
    "https://verificacion-segura-clon.org", "https://sitio-limpio-y-seguro.com",
    "http://testsafebrowsing-phishing-page.com"
]

ARCHIVOS_MALWARE = [
    "ransomware_cripto.exe", "troyano_bancario.dll", "script_limpio.py",
    "keylogger_oculto.exe", "factura_falsa.pdf.exe", "parche_actualizacion.msi"
]

# Variables globales de telemetría forense (Protegidas con Lock)
stats_lock = threading.Lock()
telemetria = {
    "exitosas": 0,
    "fallidas": 0,
    "latencias": []
}

def lanzar_peticion_ataque(id_hilo):
    """Simula un bot enviando una petición robustecida con inyección criptográfica."""
    tipo_ataque = random.choice(['phone', 'url', 'file'])
    payload = {"type": tipo_ataque}
    
    if tipo_ataque == 'phone':
        target = random.choice(TELEFONOS_ATAQUE)
        payload["target"] = target
    elif tipo_ataque == 'url':
        target = random.choice(URLS_PHISHING)
        payload["target"] = target
    else:
        target = random.choice(ARCHIVOS_MALWARE)
        payload["target"] = target
        # Generamos un hash SHA-256 único basado en el nombre para que el motor analítico no truene
        payload["sha256"] = hashlib.sha256(target.encode()).hexdigest()

    try:
        inicio = time.time()
        response = requests.post(BASE_URL, json=payload, timeout=6)
        duracion = (time.time() - inicio) * 1000  # En milisegundos
        
        with stats_lock:
            telemetria["latencias"].append(duracion)
            if response.status_code == 200:
                telemetria["exitosas"] += 1
                data = response.json()
                print(f"🔥 [REQ {id_hilo:03d}] Tipo: {tipo_ataque.upper():<5} | Veredicto: {data.get('verdict', 'UNKNOWN'):<10} | Latencia: {duracion:.2f}ms")
            else:
                telemetria["fallidas"] += 1
                print(f"❌ [REQ {id_hilo:03d}] Error de Servidor: Código {response.status_code}")
                
    except requests.exceptions.RequestException as e:
        with stats_lock:
            telemetria["fallidas"] += 1
        print(f"⚠️ [REQ {id_hilo:03d}] Fallo de conexión: {type(e).__name__}")

def ejecutar_simulador_fuerza_bruta(total_ataques=100):
    """Orquesta la ráfaga usando un pool de hilos optimizado para evitar caídas de sockets."""
    print("=" * 75)
    print("🛡️ ACTIVANDO SIMULADOR DE STRESS TEST & ROBOCALLS V2 - JOSH SECURITY")
    print(f"🚀 INYECTANDO {total_ataques} PETICIONES CONCURRENTES (Pool: {MAX_WORKERS} Workers)...")
    print("=" * 75)
    time.sleep(1.5)

    inicio_test = time.time()

    # Uso de ThreadPoolExecutor para gestionar eficientemente la concurrencia
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(lanzar_peticion_ataque, i) for i in range(1, total_ataques + 1)]
        # Espera que todos se completen
        for future in as_completed(futures):
            pass

    tiempo_total = time.time() - inicio_test

    # 📊 Reporte Forense Consolidado de la Simulación
    print("=" * 75)
    print("📊 REPORTE DE RENDIMIENTO ANALÍTICO - JOSH SECURITY")
    print("=" * 75)
    print(f"⏱️  Tiempo total de ráfaga : {tiempo_total:.2f} segundos")
    print(f"✅ Peticiones Procesadas   : {telemetria['exitosas']}")
    print(f"❌ Peticiones Fallidas     : {telemetria['fallidas']}")
    
    if telemetria["latencias"]:
        promedio = sum(telemetria["latencias"]) / len(telemetria["latencias"])
        maxima = max(telemetria["latencias"])
        print(f"📈 Latencia Promedio       : {promedio:.2f} ms")
        print(f"💥 Latencia Máxima registrada: {maxima:.2f} ms")
    print("=" * 75)
    print("📋 Proceso de estrés finalizado. Sincroniza tu interfaz en Flutter.")
    print("=" * 75)

if __name__ == "__main__":
    ejecutar_simulador_fuerza_bruta(total_ataques=100)