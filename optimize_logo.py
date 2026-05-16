import os
from PIL import Image

def optimizar_escudo_centinela(target_size=(160, 160)):
    print("[+] Inicializando Protocolo de Optimización de Activos Visuales...")
    
    # Lista de rutas posibles según tu árbol de archivos real
    posibles_rutas = [
        os.path.join("assets", "images", "logo_escudo.png"),
        os.path.join("assets", "assets", "images", "logo_escudo.png"),
        os.path.join("web", "assets", "assets", "images", "logo_escudo.png.png"),
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
        with Image.open(ruta_origen) as img:
            img = img.convert("RGBA")
            bbox = img.getbbox()
            
            if bbox:
                print("[->] Ejecutando recorte quirúrgico de bordes transparentes...")
                img = img.crop(bbox)
            
            # Redimensionado de alta definición para Flutter
            print(f"[->] Redimensionando a {target_size[0]}x{target_size[1]} píxeles...")
            img_resized = img.resize(target_size, Image.Resampling.LANCZOS)
            
            # Guardar el resultado reemplazando el original con el tamaño correcto
            img_resized.save(ruta_origen, "PNG")
            
            print(f"\n[+] ÉXITO ABSOLUTO: ¡Protocolo Centinela Completado!")
            print(f"[+] El escudo optimizado ha sido guardado e inyectado en: {ruta_origen}")
            
    except Exception as e:
        print(f"[-] ERROR CRÍTICO durante el procesamiento: {str(e)}")

if __name__ == "__main__":
    optimizar_escudo_centinela()