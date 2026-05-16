import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN

def crear_presentacion_centinela():
    print("[+] Configurando Motor de Diapositivas Ejecutivas 'Centinela 2026'...")
    prs = Presentation()
    
    # Configuración de aspecto panorámico moderno (16:9)
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    
    # Paleta Cromática Cyber-Business High Contrast
    COLOR_FONDO = RGBColor(2, 6, 23)       # Ultra Dark (#020617)
    COLOR_NEON = RGBColor(56, 189, 248)    # Azul Neón (#38BDF8)
    COLOR_TEXTO = RGBColor(148, 163, 184)  # Plata Técnico (#94A3B8)
    COLOR_EXITO = RGBColor(16, 185, 129)   # Verde Reactivo (#10B981)

    diapositivas_data = [
        {
            "titulo": "CENTINELA ENGINE: PILAR 2",
            "sub": "Conexión Estratégica del Motor de Análisis Python 3.13",
            "puntos": [
                "Ecosistema Reactivo: Integración directa entre Flutter UI y scripts de backend.",
                "Arquitectura Asíncrona: Procesamiento en segundo plano sin congelamiento visual.",
                "Objetivo del Módulo: Reemplazar simulaciones estáticas por veredictos reales."
            ]
        },
        {
            "titulo": "MECANISMO DE INGESTIÓN DE DATA",
            "sub": "Protocolo de Entrada y Sanitización de URLs",
            "puntos": [
                "Captura por TextField: Recepción en tiempo real de cadenas sospechosas.",
                "Sanitización en Python: Limpieza de expresiones regulares e inyecciones de código.",
                "Fase de Disparo: Aceleración automática del giro 3D del escudo al iniciar parsing."
            ]
        },
        {
            "titulo": "PROCESAMIENTO DE AMENAZAS",
            "sub": "Motor Analítico y Consulta de Firmas",
            "puntos": [
                "Módulo de Análisis: Inspección heurística y matching de strings peligrosos.",
                "Estructura Escalable: Preparado para integración de APIs de seguridad (VirusTotal).",
                "Clasificación Binaria: Retorno inmediato de flags de estado [LIMPIO / PELIGRO]."
            ]
        },
        {
            "titulo": "RESPUESTA REACTIVA DE LA INTERFAZ",
            "sub": "Mapeo de Canales y Retorno de Flags",
            "puntos": [
                "Mutación de Estado: Cambio instantáneo de matriz cromática basada en el payload.",
                "Retroalimentación Resonante: Efectos Glow reactivos (Verde Neón / Rojo Alerta).",
                "Persistencia de Evidencias: Inserción atómica en el Historial de Vigilancia."
            ]
        },
        {
            "titulo": "HOJA DE RUTA E INYECCIÓN DE CÓDIGO",
            "sub": "Siguientes Pasos del Despliegue Técnico",
            "puntos": [
                "Fase 1: Implementar sockets de comunicación local o API REST con Flask.",
                "Fase 2: Conectar el validador real al botón 'Escanear Ahora'.",
                "Fase 3: Refinar metadatos en la base de datos local del historial."
            ]
        }
    ]

    blank_layout = prs.slide_layouts[6] 

    for data in diapositivas_data:
        slide = prs.slides.add_slide(blank_layout)
        
        background = slide.background
        fill = background.fill
        fill.solid()
        fill.fore_color.rgb = COLOR_FONDO
        
        txBox = slide.shapes.add_textbox(Inches(0.8), Inches(0.6), Inches(11.5), Inches(1.2))
        tf = txBox.text_frame
        tf.word_wrap = True
        p = tf.paragraphs[0]
        p.text = data["titulo"]
        p.font.size = Pt(40)
        p.font.bold = True
        p.font.name = 'Arial'
        p.font.color.rgb = COLOR_NEON
        
        p_sub = tf.add_paragraph()
        p_sub.text = data["sub"]
        p_sub.font.size = Pt(18)
        p_sub.font.italic = True
        p_sub.font.name = 'Arial'
        p_sub.font.color.rgb = COLOR_EXITO
        p_sub.space_before = Pt(8)

        contentBox = slide.shapes.add_textbox(Inches(0.8), Inches(2.3), Inches(11.5), Inches(4.5))
        tf_content = contentBox.text_frame
        tf_content.word_wrap = True
        
        for i, punto in enumerate(data["puntos"]):
            p_pt = tf_content.paragraphs[0] if i == 0 else tf_content.add_paragraph()
            p_pt.text = f"▪  {punto}"
            p_pt.font.size = Pt(20)
            p_pt.font.name = 'Arial'
            p_pt.font.color.rgb = COLOR_TEXTO
            p_pt.space_before = Pt(24)
            p_pt.alignment = PP_ALIGN.LEFT

    output_filename = "Centinela_Pilar2_Conexion.pptx"
    prs.save(output_filename)
    print(f"\n[+] PRESENTACIÓN GENERADA: Documento listo en '{output_filename}'.")

if __name__ == "__main__":
    crear_presentacion_centinela()