#!/bin/bash

# ==============================================================================
# DESCARGADOR DE MÚSICA CON SPOTDL
#
# Descarga canciones, álbumes o listas de reproducción de Spotify.
# ==============================================================================

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CREDS_FILE="$HOME/.spotdl_creds"

# Cargar credenciales si existen
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
fi

echo -e "\n${CYAN}--- Descargador de Música con spotdl ---${NC}"

# Verificar si spotdl está instalado antes de continuar
if ! command -v spotdl >/dev/null 2>&1; then
    echo -e "${RED}Error: spotdl no está instalado.${NC}"
    echo "Por favor, ejecute la opción 'Verificar/Instalar spotdl' desde el menú principal."
    exit 1
fi

# Pedir la URL de Spotify
echo -e "\n${YELLOW}Introduce la URL de Spotify (canción, álbum o playlist):${NC}"
read -p "> " SPOTIFY_URL

if [[ -z "$SPOTIFY_URL" ]]; then
    echo -e "${RED}Error: URL no válida.${NC}"
    exit 1
fi

# Elegir carpeta de descarga
DEFAULT_DOWNLOAD_DIR="$HOME/Music/SpotDL"
echo -e "\n${YELLOW}Carpeta de descarga:${NC}"
echo -e "1) Predeterminada ($DEFAULT_DOWNLOAD_DIR)"
echo -e "2) Carpeta de música del sistema ($HOME/Music)"
echo -e "3) Carpeta personalizada"
read -p "Seleccione una opción (1-3): " DIR_CHOICE

case "$DIR_CHOICE" in
    1) DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR" ;;
    2) DOWNLOAD_DIR="$HOME/Music" ;;
    3) 
        read -p "Introduce la ruta completa de la carpeta: " CUSTOM_DIR
        DOWNLOAD_DIR=$(eval echo "$CUSTOM_DIR") # Para expandir ~ si es necesario
        ;;
    *) DOWNLOAD_DIR="$DEFAULT_DOWNLOAD_DIR" ;;
esac

# Crear la carpeta si no existe
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo -e "${CYAN}Creando carpeta de descarga: $DOWNLOAD_DIR...${NC}"
    mkdir -p "$DOWNLOAD_DIR"
fi

# Cambiar al directorio de descarga
cd "$DOWNLOAD_DIR" || { echo -e "${RED}Error: No se pudo acceder a la carpeta de descarga.${NC}"; exit 1; }

# Ejecutar spotdl, registrando en un archivo temporal las canciones que fallen
echo -e "\n${GREEN}Iniciando la descarga en $DOWNLOAD_DIR...${NC}"
echo -e "${CYAN}Ejecutando: spotdl download \"$SPOTIFY_URL\"${NC}\n"

ERRORS_FILE=$(mktemp)
trap 'rm -f "$ERRORS_FILE"' EXIT

spotdl download "$SPOTIFY_URL" --save-errors "$ERRORS_FILE" 2>&1 | grep -vE "Skipping|file already exists|\(duplicate\)"
RETVAL=${PIPESTATUS[0]}

# Las líneas de fecha/hora de spotdl (YYYY-MM-DD-HH-MM-SS) no son errores
ERROR_PATTERN='^([0-9]{4}(-[0-9]{2}){5}|[[:space:]]*)$'
ERROR_COUNT=$(grep -vE "$ERROR_PATTERN" "$ERRORS_FILE" 2>/dev/null | wc -l)

# Reintento automático (una pasada, con menos hilos) de las canciones fallidas
if [ "$ERROR_COUNT" -gt 0 ]; then
    FAILED_URLS=$(grep -oE 'https://open\.spotify\.com/track/[A-Za-z0-9]+' "$ERRORS_FILE" | sort -u)
    if [ -n "$FAILED_URLS" ]; then
        FIRST_ERROR_COUNT=$ERROR_COUNT
        echo -e "\n${CYAN}Reintentando (2ª pasada) las $FIRST_ERROR_COUNT canción(es) fallidas...${NC}"
        : > "$ERRORS_FILE"
        mapfile -t RETRY_URLS <<< "$FAILED_URLS"
        spotdl download "${RETRY_URLS[@]}" --save-errors "$ERRORS_FILE" --threads 1 2>&1 | grep -vE "Skipping|file already exists|\(duplicate\)"
        RETRY_RETVAL=${PIPESTATUS[0]}
        ERROR_COUNT=$(grep -vE "$ERROR_PATTERN" "$ERRORS_FILE" 2>/dev/null | wc -l)
        RECOVERED=$(( FIRST_ERROR_COUNT - ERROR_COUNT ))
        if [ "$RECOVERED" -gt 0 ]; then
            echo -e "${GREEN}✔ $RECOVERED canción(es) recuperadas en el reintento.${NC}"
        fi
        if [ "$RETVAL" -eq 0 ]; then
            RETVAL=$RETRY_RETVAL
        fi
    fi
fi

if [ $RETVAL -ne 0 ]; then
    echo -e "\n${RED}Hubo un problema durante la descarga (spotdl terminó con error $RETVAL).${NC}"
    echo "Si ves un error de 'Rate Limit (86400)', prueba a configurar tus propias"
    echo "credenciales de Spotify desde el menú principal [C]."
elif [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}Descarga finalizada, pero $ERROR_COUNT canción(es) no se pudieron bajar:${NC}"
    grep -vE "$ERROR_PATTERN" "$ERRORS_FILE" | sed 's/^/  - /'
    echo -e "\n${YELLOW}Consejo: si los errores son de tipo 'YouTube/YT-DLP', es un bloqueo temporal de YouTube; espera un poco y vuelve a ejecutar esta opción.${NC}"
else
    echo -e "\n${GREEN}¡Descarga completada correctamente!${NC}"
fi

# ------------------------------------------------------------------------------
# Verificación de archivos cortados o sospechosos (ya descargados)
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}---- Verificación de archivos cortados/truncados ----${NC}"

SUSPECT_LIST=$(python3 - "$DOWNLOAD_DIR" <<'PY'
import os
import sys

from mutagen.id3 import ID3

root = sys.argv[1]
THRESHOLD = 100 * 1024  # 100 KB por debajo de lo cual se considera sospechoso
for entry in sorted(os.listdir(root)):
    f = os.path.join(root, entry)
    if not os.path.isfile(f) or not entry.lower().endswith(".mp3"):
        continue
    try:
        size = os.path.getsize(f)
    except OSError:
        continue
    if size >= THRESHOLD:
        continue
    url = ""
    try:
        tags = ID3(f)
        if "WOAS" in tags:
            url = str(tags["WOAS"]).strip()
    except Exception:
        pass
    print(f"{size}\t{url}\t{f}")
PY
)

if [ -z "$SUSPECT_LIST" ]; then
    echo "   No se encontraron archivos sospechosos (menores a 100 KB)."
else
    echo "   Archivos sospechosos (posiblemente cortados):"
    REPAIR_URLS=()
    while IFS=$'\t' read -r size url fpath; do
        if [ -n "$url" ]; then
            echo "   - $(basename "$fpath") ($size bytes) -> reparando"
            REPAIR_URLS+=("$url")
        else
            echo "   - $(basename "$fpath") ($size bytes) -> sin URL de Spotify (no reparable)"
        fi
    done <<< "$SUSPECT_LIST"

    if [ "${#REPAIR_URLS[@]}" -gt 0 ]; then
        echo -e "\n${CYAN}Re-descargando ${#REPAIR_URLS[@]} archivo(s) cortado(s)...${NC}"
        spotdl download "${REPAIR_URLS[@]}" --save-errors "$ERRORS_FILE" --overwrite force --threads 1 2>&1 | grep -vE "Skipping|file already exists|\(duplicate\)"
        echo -e "${GREEN}Reparación finalizada.${NC}"
    else
        echo -e "\n${YELLOW}Los archivos sospechosos no tienen URL de Spotify (etiqueta WOAS); no se pueden reparar automáticamente.${NC}"
    fi
fi
