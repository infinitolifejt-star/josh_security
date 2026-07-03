import requests
import json
import hashlib
import os

def generar_hash_simulado(nombre_archivo):
    """
    Crea un archivo temporal de prueba si no existe, calcula su hash SHA-256 
    real para simular la analítica del motor forense de JOSH Security.
    """
    contenido_simulado = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
    ruta_temporal = os.path.join(os.getcwd(), nombre_archivo)
    
    # Escribimos el archivo de prueba local temporalmente
    with open(ruta_temporal, "wb") as f:
        f.write(contenido_simulado)
        
    # Calculamos el SHA-256 real del archivo generado
    sha256_hash = hashlib.sha256()
    with open(ruta_temporal, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
            
    return sha256_hash.hexdigest(), ruta_temporal

def ejecutar_diagnostico_malware():
    print("=" * 75)
    print("🧪 QA AUTOMATION - INICIANDO SIMULACIÓN DE ESCANEO DE MALWARE AVANZADO")
    print("=" * 75)

    # Cambiar a la URL de Render cuando pases a QA en la nube
    url_endpoint = "http://127.0.0.1:5000/api/v1/scan"
    nombre_muestra = "ransomware_test_sample.exe"
    
    try:
        # Generamos el hash real de la muestra para inyectarlo en el payload
        hash_real, ruta_archivo = generar_hash_simulado(nombre_muestra)
        print(f"📁 Archivo temporal generado: {nombre_muestra}")
        print(f"🔑 SHA-256 Calculado para la inyección: {hash_real}")
        print("-" * 75)
        
        # Payload robustecido enviado al backend de Python
        payload = {
            "type": "file",
            "target": nombre_muestra,
            "sha256": hash_real
        }
        
        headers = {
            "Content-Type": "application/json"
        }

        print(f"📡 Enviando solicitud POST a: {url_endpoint}")
        print(f"📦 Payload Estructurado: {json.dumps(payload, indent=4)}")
        print("-" * 75)

        response = requests.post(url_endpoint, data=json.dumps(payload), headers=headers, timeout=12)
        
        print(f"📥 Código de Respuesta del Servidor: {response.status_code}")
        print("📊 Resultado Forense Devuelto:")
        print(json.dumps(response.json(), indent=4, ensure_ascii=False))
        
        # Limpieza del entorno de pruebas
        if os.path.exists(ruta_archivo):
            os.remove(ruta_archivo)
            
    except requests.exceptions.ConnectionError:
        print("❌ Error crítico: No se pudo conectar al servidor. ¿El backend local está encendido?")
    except Exception as e:
        print(f"❌ Error crítico inesperado en la conexión de pruebas: {str(e)}")

    print("=" * 75)
    print("[🎉] PRUEBA FINALIZADA - Abre JOSH Security en tu dispositivo y presiona Sincronizar.")
    print("=" * 75)

if __name__ == '__main__':
    ejecutar_diagnostico_malware()