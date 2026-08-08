# =====================================================================
# JOSH SECURITY: QA AUTOMATION & DIAGNOSTIC SUITE
# =====================================================================
import hashlib
import json
import os
import requests


def generar_hash_simulado(nombre_archivo):
    contenido_simulado = (
        b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS"
        b"-TEST-FILE!$H+H*"
    )
    ruta_temporal = os.path.join(os.getcwd(), nombre_archivo)

    with open(ruta_temporal, "wb") as f:
        f.write(contenido_simulado)

    sha256_hash = hashlib.sha256()
    with open(ruta_temporal, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)

    return sha256_hash.hexdigest(), ruta_temporal


def ejecutar_diagnostico_malware():
    print("=" * 75)
    print("🧪 QA AUTOMATION - DIAGNÓSTICO DE MALWARE JOSH SECURITY")
    print("=" * 75)

    url_endpoint = "http://127.0.0.1:5000/api/v1/scan"
    nombre_muestra = "ransomware_test_sample.exe"

    try:
        hash_real, ruta_archivo = generar_hash_simulado(nombre_muestra)
        print(f"📁 Muestra generada: {nombre_muestra}")
        print(f"🔑 SHA-256 Inyectado: {hash_real}")
        print("-" * 75)

        payload = {
            "type": "file",
            "target": nombre_muestra,
            "sha256": hash_real,
        }

        headers = {"Content-Type": "application/json"}

        print(f"📡 Enviando solicitud a: {url_endpoint}")
        response = requests.post(
            url_endpoint,
            data=json.dumps(payload),
            headers=headers,
            timeout=12,
        )

        print(f"📥 Código HTTP: {response.status_code}")
        print("📊 Resultado Devuelto:")
        print(json.dumps(response.json(), indent=4, ensure_ascii=False))

        if os.path.exists(ruta_archivo):
            os.remove(ruta_archivo)

    except requests.exceptions.ConnectionError:
        print("❌ Error crítico: Servidor fuera de línea.")
    except Exception as e:
        print(f"❌ Error inesperado: {str(e)}")

    print("=" * 75)


if __name__ == "__main__":
    ejecutar_diagnostico_malware()
