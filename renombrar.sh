#!/bin/bash

# ==============================================================================
# RENOMBRADOR DE MP3 v1.1 (Versión Corregida)
#
# Renombra archivos MP3 al formato "Artista - Título.mp3" leyendo las
# etiquetas ID3 del propio archivo. Usa un método de lectura compatible.
#
# Requisitos: eyeD3
# ==============================================================================

# --- Colores y Dependencias ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

command -v eyeD3 >/dev/null 2>&1 || { echo -e >&2 "${RED}❌ Error: El comando 'eyeD3' es necesario pero no está instalado.${NC}"; exit 1; }

# --- Inicio del Script ---
echo -e "🎶 ${YELLOW}Iniciando Renombrador de MP3 v1.1...${NC}"
echo "============================================================"

# Inicializamos contadores
RENAMED_COUNT=0
SKIPPED_COUNT=0

for file in *.mp3; do
    [ -f "$file" ] || continue

    echo -e "🔎 Analizando: ${YELLOW}$file${NC}"

    # --- MÉTODO DE LECTURA CORREGIDO ---
    # Extraer Artista y Título usando un método más compatible
    artist=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^artist:" | sed 's/artist: *//' | tr -d '\0')
    title=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^title:" | sed 's/title: *//' | tr -d '\0')

    # --- Verificación de Seguridad 1: ¿Existen las etiquetas? ---
    if [[ -z "$artist" || -z "$title" ]]; then
        echo -e "   ${RED}✗ Omitiendo: No se encontraron etiquetas de Artista o Título.${NC}"
        ((SKIPPED_COUNT++))
        continue
    fi

    # --- Limpieza del Nombre ---
    # Reemplaza caracteres inválidos en nombres de archivo con un guion bajo.
    safe_artist=$(echo "$artist" | sed 's#[/\\?%*:|"<>]#_#g')
    safe_title=$(echo "$title" | sed 's#[/\\?%*:|"<>]#_#g')

    # Construir el nuevo nombre de archivo
    new_filename="${safe_artist} - ${safe_title}.mp3"

    # --- Verificación de Seguridad 2: ¿El nuevo nombre ya existe? ---
    if [ "$file" != "$new_filename" ] && [ -f "$new_filename" ]; then
        echo -e "   ${RED}✗ Omitiendo: El archivo destino '$new_filename' ya existe.${NC}"
        ((SKIPPED_COUNT++))
        continue
    fi

    # --- Verificación de Seguridad 3: ¿El nombre realmente necesita cambiar? ---
    if [ "$file" == "$new_filename" ]; then
        echo -e "   ${GREEN}✓ El archivo ya está nombrado correctamente.${NC}"
    else
        # Renombrar el archivo
        mv -v "$file" "$new_filename"
        ((RENAMED_COUNT++))
    fi
done

echo "============================================================"
echo -e "✅ ${GREEN}Proceso finalizado.${NC}"
echo -e "   - Archivos renombrados: ${GREEN}$RENAMED_COUNT${NC}"
echo -e "   - Archivos omitidos: ${YELLOW}$SKIPPED_COUNT${NC}"
