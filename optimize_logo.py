# =====================================================================
# PROJECT CENTINELA: ACTIVE VISUAL ASSET OPTIMIZER (v4.4.0)
# RECORTE QUIRÚRGICO DE BBOX Y RESPALDO PREVENTIVO DE MATRIZ PNG
# =====================================================================
import os
import shutil
from PIL import Image

def optimizar_escudo_centinela(target_size=(160, 160)):
    print("[+] Inicializando Protocolo de Optimización de Activos Visuales...")
    
    # Lista de rutas posibles según tu árbol de archivos real
    posibles_rutas = [
        os.path.join("assets", "images", "logo_escudo.png"),
        os.path.join("assets", "assets", "images", "logo_escudo.png"),
        os.path.join("web", "assets", "assets", "images", "logo_escudo.png"),
        "logo_escudo.png"
    ]
    
    ruta_origen = None
    
    # Buscar el archivo en la lista de sospechosos
    for ruta in posibles_rutas:
        if os.path.exists(ruta):
            ruta_origen = ruta
            break
            
    if not ruta_origen:
        print("[-] ERROR CRÍTICO: No se encontró el logo original en ninguna de las rutas del proyecto.")
        print("[!] Por seguridad, confirma que el archivo esté dentro de la carpeta 'assets/images/'.")
        return

    try:
        print(f"[->] Escudo original localizado con éxito en: {ruta_origen}")
        
        # PROTOCOLO DE SEGURIDAD: Generar copia de respaldo (.bak) antes de operar
        ruta_bak = ruta_origen + ".bak"
        if not os.path.exists(ruta_bak):
            shutil.copy2(ruta_origen, ruta_bak)
            print(f"[->] Copia de seguridad preventiva creada en: {ruta_bak}")
        
        with Image.open(ruta_origen) as img:
            img = img.convert("RGBA")
            bbox = img.getbbox()
            
            if bbox:
                print("[->] Ejecutando recorte quirúrgico de bordes transparentes...")
                img = img.crop(bbox)
            
            # Redimensionado de alta definición para rendimiento óptimo en Flutter
            print(f"[->] Redimensionando a {target_size[0]}x{target_size[1]} píxeles...")
            img_resized = img.resize(target_size, Image.Resampling.LANCZOS)
            
            # Guardar el resultado reemplazando el original con el tamaño correcto
            img_resized.save(ruta_origen, "PNG")
            
            print(f"\n[+] ÉXITO ABSOLUTO: ¡Protocolo Centinela Completado!")
            print(f"[+] El escudo optimizado ha sido inyectado con éxito en: {ruta_origen}")
            
    except Exception as e:
        print(f"[-] ERROR CRÍTICO durante el procesamiento: {str(e)}")

if __name__ == "__main__":
    optimizar_escudo_centinela()