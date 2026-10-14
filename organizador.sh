#!/bin/bash

# ==============================================================================
# ORGANIZADOR DE BIBLIOTECA MP3 (v2.4 - Corrección Final de Contadores)
#
# - v2.4: Corregido el contador de archivos movidos en la función "Consolidar",
#         aplicando la misma solución del sub-shell que se usó para el
#         contador de carpetas eliminadas.
#
# Requisitos: eyeD3
# ==============================================================================

# --- Colores y Dependencias ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

command -v eyeD3 >/dev/null 2>&1 || { echo -e >&2 "${RED}❌ Error: 'eyeD3' no encontrado.${NC}"; exit 1; }

# --- Función get_local_tag (Análisis de Texto Inteligente) ---
get_local_tag() {
    local file="$1"; local tag_name="$2"
    local raw_output
    raw_output=$(eyeD3 --no-color "$file" 2>/dev/null)
    
    if [[ -z "$raw_output" ]]; then echo "-"; return; fi

    local result=""
    case "$tag_name" in
        Artista)
            result=$(echo "$raw_output" | grep -i "artist:" | sed -e 's/.*[aA]rtist: *//' | head -n 1)
            ;;
        Año)
            result=$(echo "$raw_output" | grep -i "recording date:" | sed 's/.*[dD]ate: *//' | head -n 1)
            ;;
        Género)
            result=$(echo "$raw_output" | grep -i "genre:" | sed -e 's/.*[gG]enre: *//' -e 's/ (id.*//' | head -n 1)
            ;;
        BPM)
            result=$(echo "$raw_output" | grep -i "^BPM:" | sed 's/.*BPM: *//' | head -n 1)
            ;;
        *)
            result="-"
            ;;
    esac
    
    if [[ -z "$result" || "$result" == "Null" ]]; then
        echo "-"
    else
        echo "$result" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
    fi
}

# --- Función para limpiar nombres para directorios ---
sanitize_name() {
    echo "$1" | sed 's#[/\\?%*:|"<>]#_#g'
}

# ==============================================================================
# --- INICIO DEL SCRIPT PRINCIPAL ---
# ==============================================================================
echo -e "🎶 ${CYAN}Iniciando Organizador de Biblioteca MP3 v2.4...${NC}"
echo "================================================================="

# --- Menú Interactivo ---
echo -e "Selecciona una tarea de organización:"
echo -e "  ${YELLOW}--- Clasificar en Carpetas ---${NC}"
echo -e "  1) Por Década"
echo -e "  2) Por Género Musical"
echo -e "  3) Por BPM"
echo -e "  4) Por Artista"
echo -e "  ${YELLOW}--- Mantenimiento ---${NC}"
echo -e "  5) ${CYAN}Consolidar MP3s en esta carpeta${NC}"
echo
echo -e "  6) ${RED}Salir${NC}"
echo

read -p "¿Opción (1-6): " CHOICE

# Inicializar contadores
MOVED_COUNT=0
SKIPPED_COUNT=0
DELETED_DIR_COUNT=0

# --- Lógica principal basada en la elección ---
case "$CHOICE" in
    1|2|3|4) # --- LÓGICA DE CLASIFICACIÓN ---
        case "$CHOICE" in
            1) CRITERION="Década";;
            2) CRITERION="Género Musical";;
            3) CRITERION="BPM";;
            4) CRITERION="Artista";;
        esac
        echo -e "\n${CYAN}Organizando por $CRITERION...${NC}"

        for file in *.mp3; do
            [ -f "$file" ] || continue
            
            dir_name=""
            tag_value=""

            case "$CHOICE" in
                1) # Década
                    tag_value=$(get_local_tag "$file" "Año")
                    if [[ "$tag_value" =~ ^[0-9]{4}$ ]]; then
                        decade_start=${tag_value:0:3}0
                        dir_name="Década de los ${decade_start}s"
                    fi
                    ;;
                2) # Género
                    tag_value=$(get_local_tag "$file" "Género")
                    if [[ -n "$tag_value" && "$tag_value" != "-" ]]; then
                        clean_genre=$(echo "$tag_value" | sed -e "s/\b\(.\)/\u\1/g")
                        dir_name=$(sanitize_name "$clean_genre")
                    fi
                    ;;
                3) # BPM
                    tag_value=$(get_local_tag "$file" "BPM")
                    if [[ "$tag_value" =~ ^[0-9]+$ && "$tag_value" -gt 0 ]]; then
                        range_start=$(( (tag_value / 10) * 10 ))
                        range_end=$(( range_start + 9 ))
                        dir_name="BPM ${range_start}-${range_end}"
                    fi
                    ;;
                4) # Artista
                    tag_value=$(get_local_tag "$file" "Artista")
                    if [[ -n "$tag_value" && "$tag_value" != "-" ]]; then
                        dir_name=$(sanitize_name "$tag_value")
                    fi
                    ;;
            esac

            if [ -n "$dir_name" ]; then
                echo -e "   ${GREEN}Moviendo '$file' a la carpeta '$dir_name'${NC}"
                mkdir -p "$dir_name"
                mv -v "$file" "$dir_name/"
                ((MOVED_COUNT++))
            else
                echo -e "   ${YELLOW}Omitiendo '$file': No se encontró la etiqueta requerida.${NC}"
                ((SKIPPED_COUNT++))
            fi
        done
        ;;
    
    5) # --- CONSOLIDAR MP3s ---
        echo -e "\n${CYAN}Iniciando consolidación de archivos MP3...${NC}"
        # --- BUCLE CORREGIDO PARA EL CONTADOR DE ARCHIVOS ---
        # Usamos < <(find...) para evitar el subshell que reiniciaba el contador
        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            target_file="$filename"

            if [ -f "$target_file" ]; then
                name_no_ext="${filename%.*}"
                extension="${filename##*.}"
                c=2
                while [ -f "${name_no_ext}_${c}.${extension}" ]; do
                    ((c++))
                done
                target_file="${name_no_ext}_${c}.${extension}"
                echo -e "   ${YELLOW}¡Duplicado! Renombrando '$filename' a '$target_file'${NC}"
            fi

            mv -v "$file" "$target_file"
            ((MOVED_COUNT++))
        done < <(find . -mindepth 2 -type f -iname "*.mp3" -print0)

        echo -e "\n${CYAN}Buscando y eliminando subcarpetas vacías...${NC}"
        while IFS= read -r dir; do
            echo -e "   ${RED}✓ Carpeta vacía eliminada: $dir${NC}"
            ((DELETED_DIR_COUNT++))
        done < <(find . -mindepth 1 -type d -empty -print -delete)
        ;;

    6) # --- SALIR ---
        echo -e "\n${GREEN}Saliendo del organizador.${NC}"
        exit 0
        ;;

    *) # --- OPCIÓN INVÁLIDA ---
        echo -e "\n${RED}Opción no válida. Saliendo del script.${NC}"
        exit 1
        ;;
esac

echo "================================================================="
echo -e "✅ ${GREEN}Proceso finalizado.${NC}"
if [ "$CHOICE" -eq 5 ]; then
    echo -e "   - Archivos movidos a la carpeta raíz: ${GREEN}$MOVED_COUNT${NC}"
    echo -e "   - Subcarpetas vacías eliminadas: ${RED}$DELETED_DIR_COUNT${NC}"
else
    echo -e "   - Archivos movidos: ${GREEN}$MOVED_COUNT${NC}"
    echo -e "   - Archivos omitidos: ${YELLOW}$SKIPPED_COUNT${NC}"
fi
