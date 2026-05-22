import threading
import requests
import random
import time

# Configuración del ecosistema local
BASE_URL = "http://127.0.0.1:5000/api/v1/scan"

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

def lanzar_peticion_ataque(id_hilo):
    """Simula un bot enviando una petición aleatoria al Core de JOSH SECURITY."""
    tipo_ataque = random.choice(['phone', 'url', 'file'])
    
    if tipo_ataque == 'phone':
        target = random.choice(TELEFONOS_ATAQUE)
    elif tipo_ataque == 'url':
        target = random.choice(URLS_PHISHING)
    else:
        target = random.choice(ARCHIVOS_MALWARE)

    payload = {
        "type": tipo_ataque,
        "target": target
    }

    try:
        inicio = time.time()
        response = requests.post(BASE_URL, json=payload, timeout=5)
        duracion = (time.time() - inicio) * 1000 # Convertir a milisegundos
        
        if response.status_code == 200:
            data = response.json()
            print(f"🔥 [HILO {id_hilo:03d}] Tipo: {tipo_ataque.upper()} | Objetivo: {target} "
                  f"| Veredicto: {data.get('verdict')} | Latencia: {duracion:.2f}ms")
        else:
            print(f"❌ [HILO {id_hilo:03d}] Error de Servidor: Código {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        print(f"⚠️ [HILO {id_hilo:03d}] Fallo de conexión: {e}")

def ejecutar_simulador_fuerza_bruta(total_ataques=100):
    """Orquesta la ráfaga concurrente usando hilos en paralelo."""
    print("=" * 70)
    print("🛡️ ACTIVANDO SIMULADOR DE STRESS TEST & ROBOCALLS - JOSH SECURITY")
    print(f"🚀 INYECTANDO {total_ataques} PETICIONES SIMULTÁNEAS EN LA RED LOCAL...")
    print("=" * 70)
    time.sleep(2)

    hilos = []
    
    for i in range(1, total_ataques + 1):
        hilo = threading.Thread(target=lanzar_peticion_ataque, args=(i,))
        hilos.append(hilo)
        hilo.start()

    # Esperar a que todos los hilos terminen su ejecución
    for hilo in hilos:
        hilo.join()

    print("=" * 70)
    print("✅ SIMULACIÓN DE TRÁFICO CONCURRENTES FINALIZADA")
    print("📋 Revisa la interfaz de Flutter y dale 'Sincronizar' para ver los logs inyectados.")
    print("=" * 70)

if __name__ == "__main__":
    ejecutar_simulador_fuerza_bruta(total_ataques=100)