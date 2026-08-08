# =====================================================================
# JOSH SECURITY: ACTIVE VISUAL ASSET OPTIMIZER
# RECORTE QUIRÚRGICO DE BBOX Y RESPALDO PREVENTIVO DE MATRIZ PNG
# =====================================================================
import os
import shutil
from PIL import Image


def optimizar_escudo_josh(target_size=(160, 160)):
    print("[+] Inicializando Protocolo de Optimización de Activos...")

    posibles_rutas = [
        os.path.join("assets", "images", "logo_escudo.png"),
        os.path.join("assets", "assets", "images", "logo_escudo.png"),
        os.path.join("web", "assets", "assets", "images", "logo_escudo.png"),
        "logo_escudo.png",
    ]

    ruta_origen = None

    for ruta in posibles_rutas:
        if os.path.exists(ruta):
            ruta_origen = ruta
            break

    if not ruta_origen:
        print("[-] ERROR CRÍTICO: No se encontró el logo original.")
        print("[!] Confirma que el archivo esté dentro de 'assets/images/'.")
        return

    try:
        print(f"[->] Escudo original localizado en: {ruta_origen}")

        ruta_bak = ruta_origen + ".bak"
        if not os.path.exists(ruta_bak):
            shutil.copy2(ruta_origen, ruta_bak)
            print(f"[->] Copia de seguridad creada en: {ruta_bak}")

        with Image.open(ruta_origen) as img:
            img = img.convert("RGBA")
            bbox = img.getbbox()

            if bbox:
                print("[->] Ejecutando recorte quirúrgico de bordes...")
                img = img.crop(bbox)

            print(
                f"[->] Redimensionando a "
                f"{target_size[0]}x{target_size[1]}..."
            )
            img_resized = img.resize(target_size, Image.Resampling.LANCZOS)
            img_resized.save(ruta_origen, "PNG")

            print("\n[+] ÉXITO ABSOLUTO: Escudo optimizado correctamente.")

    except Exception as e:
        print(f"[-] ERROR CRÍTICO durante el procesamiento: {str(e)}")


if __name__ == "__main__":
    optimizar_escudo_josh()
