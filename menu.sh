#!/bin/bash

# ==============================================================================
# MENÚ PRINCIPAL DEL GESTOR DE MÚSICA v1.2 (UI/UX Mejorado)
#
# - v1.2: Reestructurado el menú para mayor claridad y legibilidad.
#       - Se usan letras para opciones de mantenimiento (I, S).
#       - Se corrigieron los colores y el formato de la descripción.
#       - Eliminada la opción duplicada/errónea.
#
# Lanza de forma centralizada todas las herramientas de gestión.
# ==============================================================================

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'  # Color principal para las opciones
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Localización de los Scripts ---
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --- Rutas a los Scripts ---
RENOMBRAR_SCRIPT="$SCRIPT_DIR/renombrar.sh"
COMPLETAR_SCRIPT="$SCRIPT_DIR/completar.sh"
COMPARADOR_SCRIPT="$SCRIPT_DIR/comparadorsmart.sh"
ORGANIZADOR_SCRIPT="$SCRIPT_DIR/organizador.sh"
DESCARGAR_SCRIPT="$SCRIPT_DIR/descargar.sh"
CHECK_SPOTDL_SCRIPT="$SCRIPT_DIR/check_spotdl.sh"
CONFIGURAR_SCRIPT="$SCRIPT_DIR/configurar_spotdl.sh"

# --- Función de Instalación de Dependencias ---
install_dependencies() {
    echo -e "\n${CYAN}--- Instalador de Dependencias ---${NC}"
    echo "Este proceso intentará instalar todos los paquetes necesarios para el"
    echo "correcto funcionamiento de todos los scripts."
    echo -e "Se requerirán privilegios de administrador (sudo).\n"

    if ! command -v apt-get >/dev/null; then
        echo -e "${YELLOW}No se detectó el gestor de paquetes APT.${NC}"
        echo "Por favor, instala las siguientes dependencias manualmente:"
        echo "  - Paquetes de sistema: eyeD3, ffmpeg, bpm-tools, curl, jq, libchromaprint-tools, python3-pip"
        echo "  - Paquete de Python: sudo pip3 install pyacoustid"
        return
    fi

    echo "Sistema basado en Debian/Ubuntu detectado."
    local system_packages="eyed3 ffmpeg bpm-tools curl jq libchromaprint-tools python3 python3-pip"
    local python_packages="pyacoustid"

    echo -e "Paquetes de sistema a instalar: ${YELLOW}$system_packages${NC}"
    echo -e "Paquetes de Python a instalar: ${YELLOW}$python_packages${NC}"
    
    read -p "¿Desea continuar con la instalación? (S/N): " confirm
    if [[ "${confirm^^}" != "S" ]]; then
        echo "Instalación cancelada."
        return
    fi

    echo -e "\n${CYAN}1. Actualizando lista de paquetes (se podría solicitar contraseña de sudo)...${NC}"
    sudo apt-get update || { echo -e "${RED}Error al actualizar la lista de paquetes.${NC}"; return; }

    echo -e "\n${CYAN}2. Instalando paquetes del sistema...${NC}"
    sudo apt-get install -y $system_packages || { echo -e "${RED}Error durante la instalación de paquetes del sistema.${NC}"; return; }

    echo -e "\n${CYAN}3. Instalando paquetes de Python con pip3...${NC}"
    sudo pip3 install --break-system-packages $python_packages || { echo -e "${RED}Error durante la instalación de paquetes de Python.${NC}"; return; }

    echo -e "\n${GREEN}¡Instalación completada con éxito!${NC}"
    echo "Todos los paquetes necesarios deberían estar instalados."
}


# --- Bucle del Menú Principal ---
while true; do
    clear
    echo -e "${CYAN}=============================================${NC}"
    echo -e "  🎶 ${YELLOW}GESTOR DE BIBLIOTECA MUSICAL${NC} 🎶"
    echo -e "${CYAN}=============================================${NC}"
    echo "Ubicación de trabajo actual: $(pwd)"
    echo
    echo -e "${YELLOW}[I] Instalar Dependencias${NC}"
    echo -e "   └─ Instala todas las herramientas necesarias (ejecutar la primera vez)."
    echo
    echo -e "${CYAN}[1] Renombrar Archivos${NC}"
    echo -e "   └─ Nombra los MP3 al formato 'Artista - Título.mp3'."
    echo
    echo -e "${CYAN}[2] Completar Metadatos${NC}"
    echo -e "   └─ Busca y añade online datos faltantes (BPM, año, género, etc.)."
    echo
    echo -e "${CYAN}[3] Buscar Duplicados${NC}"
    echo -e "   └─ Encuentra duplicados por sonido y compara su calidad."
    echo
    echo -e "${CYAN}[4] Organizar Biblioteca${NC}"
    echo -e "   └─ Menú para clasificar en carpetas o consolidar todo en una."
    echo
    echo -e "${GREEN}[5] Descargar Música${NC}"
    echo -e "   └─ Descarga canciones o playlists desde Spotify usando spotdl."
    echo
    echo -e "${YELLOW}[D] Instalar/Actualizar Herramientas${NC}"
    echo -e "   └─ Revisa si tienes lo necesario para descargar música."
    echo
    echo -e "${YELLOW}[C] Configurar Credenciales Spotify${NC}"
    echo -e "   └─ Evita límites de descarga usando tus propias claves."
    echo
    echo -e "${RED}[S] Salir${NC}"
    echo -e "${CYAN}=============================================${NC}"

    read -p "Seleccione una opción [1-5, I, D, C, S]: " choice

    case "${choice^^}" in # Usamos ^^ para convertir la opción a mayúsculas
        I) install_dependencies ;;
        
        1) echo -e "\n${YELLOW}Iniciando Renombrador...${NC}"; bash "$RENOMBRAR_SCRIPT" ;;
        
        2) echo -e "\n${YELLOW}Iniciando Completador de Metadatos...${NC}"; bash "$COMPLETAR_SCRIPT" ;;

        3) echo -e "\n${YELLOW}Iniciando Buscador de Duplicados...${NC}"; bash "$COMPARADOR_SCRIPT" ;;

        4) echo -e "\n${YELLOW}Iniciando Organizador de Biblioteca...${NC}"; bash "$ORGANIZADOR_SCRIPT" ;;

        5) echo -e "\n${YELLOW}Iniciando Descargador de Música...${NC}"; bash "$DESCARGAR_SCRIPT" ;;

        D) echo -e "\n${YELLOW}Verificando Requisitos de spotdl...${NC}"; bash "$CHECK_SPOTDL_SCRIPT" ;;

        C) echo -e "\n${YELLOW}Configurando Credenciales de Spotify...${NC}"; bash "$CONFIGURAR_SCRIPT" ;;

        S) echo -e "\n${GREEN}¡Hasta luego!${NC}"; exit 0 ;;

        *) echo -e "\n${RED}Opción no válida. Por favor, intente de nuevo.${NC}" ;;
    esac

    echo -e "\n${CYAN}---------------------------------------------${NC}"
    read -p "Presione Enter para volver al menú principal..."
done
