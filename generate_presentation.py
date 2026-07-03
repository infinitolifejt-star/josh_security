# =====================================================================
# PROJECT CENTINELA: AUTOMATED SLIDE COMPILER (v4.4.0 - PRODUCTION)
# AUDITORÍA DE CONTENEDORES VISUALES Y ACTUALIZACIÓN DE HOJA DE RUTA
# =====================================================================
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

    # Actualización Forense de la Data: Reflejando estado v4.4.0 de Producción
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
            "sub": "Protocolo de Entrada y Sanitización de Vectores",
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
                "Estructura Escalable: Conexión nativa a las APIs de VirusTotal y Google Safe Browsing.",
                "Clasificación Binaria: Retorno inmediato de flags de estado [SAFE / WARNING / DANGER]."
            ]
        },
        {
            "titulo": "RESPUESTA REACTIVA DE LA INTERFAZ",
            "sub": "Mapeo de Canales y Retorno de Flags",
            "puntos": [
                "Mutación de Estado: Cambio instantáneo de matriz cromática basada en el payload.",
                "Retroalimentación Resonante: Efectos Glow reactivos (Verde Neón / Rojo Alerta).",
                "Persistencia de Evidencias: Inserción atómica en el Historial de Vigilancia SQLite."
            ]
        },
        {
            "titulo": "HOJA DE RUTA E INFRAESTRUCTURA CLOUD",
            "sub": "Siguientes Pasos del Despliegue Técnico y Escalamiento",
            "puntos": [
                "Fase 1: Migración completa de servicios locales a entorno Cloud en Render.",
                "Fase 2: Implementación de Webhooks reactivos para bloqueo de llamadas SPAM.",
                "Fase 3: Auditoría forense periódica de logs blindados por firmas SHA-256."
            ]
        }
    ]

    blank_layout = prs.slide_layouts[6] 

    for data in diapositivas_data:
        slide = prs.slides.add_slide(blank_layout)
        
        # Aplicación del fondo plano oscuro institucional
        background = slide.background
        fill = background.fill
        fill.solid()
        fill.fore_color.rgb = COLOR_FONDO
        
        # Caja de Encabezado (Título y Subtítulo)
        txBox = slide.shapes.add_textbox(Inches(0.8), Inches(0.6), Inches(11.5), Inches(1.5))
        tf = txBox.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        
        p = tf.paragraphs[0]
        p.text = data["titulo"]
        p.font.size = Pt(38)
        p.font.bold = True
        p.font.name = 'Arial'
        p.font.color.rgb = COLOR_NEON
        
        p_sub = tf.add_paragraph()
        p_sub.text = data["sub"]
        p_sub.font.size = Pt(16)
        p_sub.font.italic = True
        p_sub.font.name = 'Arial'
        p_sub.font.color.rgb = COLOR_EXITO
        p_sub.space_before = Pt(6)

        # Caja de Contenido (Viñetas Analíticas)
        contentBox = slide.shapes.add_textbox(Inches(0.8), Inches(2.4), Inches(11.5), Inches(4.3))
        tf_content = contentBox.text_frame
        tf_content.word_wrap = True
        tf_content.margin_left = tf_content.margin_right = tf_content.margin_top = tf_content.margin_bottom = 0
        
        for i, punto in enumerate(data["puntos"]):
            # Corregimos el bug de python-pptx purgando la viñeta inicial del contenedor
            p_pt = tf_content.paragraphs[0] if i == 0 else tf_content.add_paragraph()
            p_pt.text = f"▪  {punto}"
            p_pt.font.size = Pt(20)
            p_pt.font.name = 'Arial'
            p_pt.font.color.rgb = COLOR_TEXTO
            p_pt.space_before = Pt(20)
            p_pt.alignment = PP_ALIGN.LEFT

    output_filename = "Centinela_Pilar2_Conexion.pptx"
    prs.save(output_filename)
    print(f"\n[+] PRESENTACIÓN REFACTORIZADA: Archivo corporativo blindado en '{output_filename}'.")

if __name__ == "__main__":
    crear_presentacion_centinela()