import os
import requests
from dotenv import load_dotenv

# Cargar las variables de entorno desde el archivo .env
load_dotenv()

class APINinjasSecurityService:
    def __init__(self):
        # Obtener la llave cargada desde el .env
        self.api_key = os.getenv("API_NINJA_KEY")
        self.base_url = "https://api.api-ninjas.com/v1"
        self.headers = {"X-Api-Key": self.api_key} if self.api_key else {}

    def validar_correo(self, email: str) -> dict:
        """
        Verifica si un correo es válido, si es temporal/desechable y si tiene registros MX.
        """
        if not self.api_key:
            return {"exito": False, "error": "Llave API_NINJA_KEY no encontrada en .env"}

        endpoint = f"{self.base_url}/validateemail?email={email}"
        try:
            response = requests.get(endpoint, headers=self.headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return {
                    "exito": True,
                    "email": email,
                    "es_valido": data.get("is_valid", False),
                    "es_desechable": data.get("is_disposable", False),
                    "tiene_mx": data.get("has_mx_records", False)
                }
            return {"exito": False, "error": f"Error HTTP {response.status_code}: {response.text}"}
        except Exception as e:
            return {"exito": False, "error": str(e)}

    def validar_ip(self, ip_address: str) -> dict:
        """
        Obtiene geolocalización de red y detecta si la IP es un Proxy o VPN.
        """
        if not self.api_key:
            return {"exito": False, "error": "Llave API_NINJA_KEY no encontrada en .env"}

        endpoint = f"{self.base_url}/iplookup?address={ip_address}"
        try:
            response = requests.get(endpoint, headers=self.headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                return {
                    "exito": True,
                    "ip": ip_address,
                    "pais": data.get("country", "Desconocido"),
                    "ciudad": data.get("city", "Desconocida"),
                    "es_proxy": data.get("is_proxy", False)
                }
            return {"exito": False, "error": f"Error HTTP {response.status_code}: {response.text}"}
        except Exception as e:
            return {"exito": False, "error": str(e)}

# --- BLOQUE DE PRUEBA LOCAL ---
if __name__ == "__main__":
    servicio = APINinjasSecurityService()

    print("\n--- PRUEBA DE VALIDACIÓN DE CORREO ---")
    resultado_correo = servicio.validar_correo("test@yopmail.com")
    print(resultado_correo)

    print("\n--- PRUEBA DE VALIDACIÓN DE IP ---")
    resultado_ip = servicio.validar_ip("8.8.8.8")
    print(resultado_ip)
