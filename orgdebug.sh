#!/bin/bash

# ==============================================================================
# SCRIPT DE DEPURACIÓN PARA ORGANIZADOR (v-debug)
#
# Este script no moverá ningún archivo. Su único propósito es ejecutar eyeD3
# en el primer archivo MP3 que encuentre, mostrar la salida completa y parar.
# Esto nos permitirá ver el formato exacto de las etiquetas.
# ==============================================================================

# Activa el modo de depuración de Bash para ver cada comando que se ejecuta
set -x

# --- Colores ---
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Encuentra el primer archivo .mp3 en el directorio
for file in *.mp3; do
    # Nos aseguramos de que sea un archivo real antes de procesarlo
    [ -f "$file" ] || continue

    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "🔎 Analizando el archivo: ${YELLOW}$file${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo "A continuación se muestra la salida COMPLETA de 'eyeD3 --no-color' para este archivo:"
    echo

    # --- COMANDO DE DIAGNÓSTICO ---
    # Ejecutamos eyeD3 sin ningún filtro para ver toda la información que contiene.
    eyeD3 --no-color "$file"

    echo
    echo -e "${CYAN}=====================================================${NC}"
    echo "Depuración finalizada. Por favor, comparte la salida completa."
    echo -e "${CYAN}=====================================================${NC}"
    
    # Salimos del bucle y del script después de analizar el primer archivo
    exit 0
done

# Si no se encuentra ningún archivo mp3
echo "No se encontraron archivos .mp3 en este directorio."
