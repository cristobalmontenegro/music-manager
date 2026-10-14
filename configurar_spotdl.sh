#!/bin/bash

# ==============================================================================
# CONFIGURADOR DE CREDENCIALES SPOTIFY PARA SPOTDL
#
# Permite al usuario usar sus propias credenciales para evitar Rate Limits.
# Actualiza tanto el entorno como el archivo de configuración de spotdl.
# ==============================================================================

# --- Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CREDS_FILE="$HOME/.spotdl_creds"
SPOTDL_CONFIG="$HOME/.spotdl/config.json"
SPOTIFY_CACHE="$HOME/.spotdl/.spotipy"

echo -e "\n${CYAN}--- Configuración de Credenciales de Spotify ---${NC}"
echo -e "Si ves el error ${RED}Rate Limit (86400)${NC}, es porque estás usando las"
echo "credenciales compartidas de spotdl. Usar las tuyas propias soluciona esto."

echo -e "\n${YELLOW}Pasos para obtener tus credenciales:${NC}"
echo "1. Ve a: https://developer.spotify.com/dashboard"
echo "2. Inicia sesión y haz clic en 'Create App'."
echo "3. Ponle cualquier nombre (ej: 'MySpotDL')."
echo "4. En 'Redirect URI' pon: http://localhost:8888/callback"
echo "5. Guarda y haz clic en 'Settings' para ver tu Client ID y Client Secret."

echo -e "\n${CYAN}---------------------------------------------${NC}"

if [ -f "$CREDS_FILE" ]; then
    echo -e "${GREEN}Ya tienes una configuración guardada.${NC}"
    source "$CREDS_FILE"
    echo "Client ID actual: ${SPOTIPY_CLIENT_ID:0:5}****************"
    read -p "¿Deseas cambiarla? (S/N): " change
    if [[ "${change^^}" != "S" ]]; then
        exit 0
    fi
fi

read -p "Introduce tu Client ID: " CLIENT_ID
read -p "Introduce tu Client Secret: " CLIENT_SECRET

if [[ -n "$CLIENT_ID" && -n "$CLIENT_SECRET" ]]; then
    # 1. Guardar para el entorno
    echo "export SPOTIPY_CLIENT_ID='$CLIENT_ID'" > "$CREDS_FILE"
    echo "export SPOTIPY_CLIENT_SECRET='$CLIENT_SECRET'" >> "$CREDS_FILE"
    echo "export SPOTIPY_REDIRECT_URI='http://localhost:8888/callback'" >> "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"

    # 2. Actualizar config.json si existe (usando sed para evitar dependencias de jq)
    if [ -f "$SPOTDL_CONFIG" ]; then
        echo -e "${CYAN}Actualizando archivo de configuración de spotdl...${NC}"
        sed -i "s/\"client_id\": \".*\"/\"client_id\": \"$CLIENT_ID\"/" "$SPOTDL_CONFIG"
        sed -i "s/\"client_secret\": \".*\"/\"client_secret\": \"$CLIENT_SECRET\"/" "$SPOTDL_CONFIG"
    fi

    # 3. Limpiar caché de Spotify (¡IMPORTANTE para el Rate Limit!)
    if [ -f "$SPOTIFY_CACHE" ]; then
        echo -e "${YELLOW}Limpiando caché de Spotify antigua...${NC}"
        rm "$SPOTIFY_CACHE"
    fi

    echo -e "\n${GREEN}¡Configuración guardada correctamente!${NC}"
    echo "Se han actualizado las credenciales y limpiado la caché."
else
    echo -e "\n${RED}Error: Ambas claves son necesarias.${NC}"
fi

true
