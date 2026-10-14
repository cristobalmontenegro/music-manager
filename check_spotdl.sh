#!/bin/bash

# ==============================================================================
# VERIFICADOR DE REQUISITOS PARA SPOTDL
#
# Verifica e instala las dependencias necesarias para descargar música de Spotify.
# ==============================================================================

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "\n${CYAN}--- Verificador de Requisitos para spotdl ---${NC}"

# 1. Verificar Python3
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}✗ Python3 no está instalado.${NC}"
    MISSING_DEPENDENCIES=true
else
    echo -e "${GREEN}✓ Python3 está instalado.${NC}"
fi

# 2. Verificar pip3
if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${RED}✗ pip3 (Python package manager) no está instalado.${NC}"
    MISSING_DEPENDENCIES=true
else
    echo -e "${GREEN}✓ pip3 está instalado.${NC}"
fi

# 3. Verificar ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${RED}✗ ffmpeg no está instalado (necesario para la conversión de audio).${NC}"
    MISSING_DEPENDENCIES=true
else
    echo -e "${GREEN}✓ ffmpeg está instalado.${NC}"
fi

# 4. Verificar spotdl
if ! command -v spotdl >/dev/null 2>&1; then
    echo -e "${RED}✗ spotdl no está instalado.${NC}"
    MISSING_DEPENDENCIES=true
else
    echo -e "${GREEN}✓ spotdl está instalado.${NC}"
fi

if [ "$MISSING_DEPENDENCIES" = true ]; then
    echo -e "\n${YELLOW}Faltan algunas dependencias. ¿Deseas intentar instalarlas ahora?${NC}"
    read -p "(S/N): " confirm
    if [[ "${confirm^^}" == "S" ]]; then
        echo -e "\n${CYAN}Iniciando instalación...${NC}"
        
        # Instalar ffmpeg y python3-pip si es necesario
        if ! command -v apt-get >/dev/null 2>&1; then
            echo -e "${RED}No se detectó el gestor de paquetes APT. Por favor, instala ffmpeg y python3-pip manualmente.${NC}"
        else
            sudo apt-get update
            sudo apt-get install -y ffmpeg python3-pip
        fi
        
        # Instalar spotdl y yt-dlp usando pip3
        echo -e "\n${CYAN}Instalando/Actualizando spotdl y yt-dlp vía pip3...${NC}"
        pip3 install --upgrade spotdl yt-dlp --break-system-packages
        
        if command -v spotdl >/dev/null 2>&1; then
            echo -e "\n${GREEN}¡Herramientas instaladas/actualizadas correctamente!${NC}"
        else
            # Intentar ver si está en el PATH del usuario (común con pip install)
            if [ -f "$HOME/.local/bin/spotdl" ]; then
                echo -e "${YELLOW}spotdl se instaló en $HOME/.local/bin/. Asegúrate de que esté en tu PATH.${NC}"
            else
                echo -e "${RED}Hubo un problema instalando spotdl. Intenta ejecutar: pip3 install spotdl${NC}"
            fi
        fi
    else
        echo -e "\n${YELLOW}Instalación cancelada.${NC}"
    fi
else
    echo -e "\n${GREEN}¡Todos los requisitos para spotdl están presentes!${NC}"
    echo -e "${YELLOW}¿Deseas buscar actualizaciones para spotdl y yt-dlp?${NC} (Recomendado si tienes errores de descarga)"
    read -p "(S/N): " update_now
    if [[ "${update_now^^}" == "S" ]]; then
        echo -e "\n${CYAN}Actualizando herramientas...${NC}"
        pip3 install --upgrade spotdl yt-dlp --break-system-packages
        echo -e "\n${GREEN}Proceso de actualización terminado.${NC}"
    fi
fi

true
