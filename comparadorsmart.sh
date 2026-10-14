#!/bin/bash

# ==============================================================================
# GESTOR MUSICAL INTERACTIVO v8.1 (Versión Definitiva)
#
# Combina la detección perceptual de audio (para encontrar duplicados reales)
# con el análisis de calidad detallado (para decidir cuál conservar),
# mostrando la tabla de comparación completa para decisiones manuales.
#
# Requisitos: libchromaprint-tools, ffmpeg, bpm-tools, eyeD3, pyacoustid
#             y el script 'reconocedor.py' en la misma carpeta.
# ==============================================================================

# --- Colores y Dependencias ---
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PYTHON_RECOGNIZER="$SCRIPT_DIR/reconocedor.py"

command -v fpcalc >/dev/null 2>&1 || { echo >&2 "❌ Error: 'fpcalc' no encontrado..."; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "❌ Error: 'ffmpeg' no encontrado..."; exit 1; }
command -v eyeD3 >/dev/null 2>&1 || { echo >&2 "❌ Error: 'eyeD3' no encontrado..."; exit 1; }
command -v bpm >/dev/null 2>&1 || { echo >&2 "❌ Error: 'bpm' no encontrado..."; exit 1; }
[ -f "$PYTHON_RECOGNIZER" ] || { echo >&2 "❌ Error: No se encuentra '$PYTHON_RECOGNIZER'."; exit 1; }


# --- Variables Globales ---
declare -A music_ids
DUPLICATES_DIR="duplicados"
DAMAGED_DIR="dañados"


# --- Función para obtener una etiqueta local específica ---
get_local_tag() {
    local file="$1"
    local tag_name="$2"
    local result
    case "$tag_name" in
        Artista)    result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^artist:" | sed 's/artist: *//' | tr -d '\0') ;;
        Titulo)     result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^title:" | sed 's/title: *//' | tr -d '\0') ;;
        Año)        result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^recording date:" | awk '{print $3}') ;;
        Género)     result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^genre:" | sed -e 's/genre: *//' -e 's/ (id=[0-9]*)//') ;;
        Album)      result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^album:" | sed -e 's/album: *//' -e 's/ (artist:.*)//') ;;
        AlbumArt)   eyeD3 --no-color "$file" 2>/dev/null | grep -aq "Attached picture:" && result="Sí" || result="No" ;;
        NumPista)   result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^track:" | awk '{print $2}') ;;
        NumDisco)   result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^disc:" | awk '{print $2}') ;;
        Compositor) result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^composer:" | sed 's/composer: *//' | tr -d '\0') ;;
        BPM)        result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^BPM:" | awk '{print $2}') ;;
        *)          result="" ;;
    esac
    echo "${result:--}"
}

# --- Función para formatear celdas con color ---
format_cell() {
    local value="$1"
    local color="$2"
    printf "${color}%-45s${NC}" "$value"
}


# --- Función principal para procesar un par de duplicados ---
process_duplicate_pair() {
    local file_A="$1"
    local file_B="$2"
    local music_id_key="$3"
    local differences=0

    # --- 1. OBTENER Y COMPARAR DATOS TÉCNICOS ---
    bitrate_A=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nw=1:nk=1 "$file_A")
    bitrate_B=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nw=1:nk=1 "$file_B")
    if [[ "$bitrate_A" != "$bitrate_B" ]]; then ((differences++)); fi

    duration_A=$(printf "%.2f" "$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file_A")")
    duration_B=$(printf "%.2f" "$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file_B")")
    if [[ "$duration_A" != "$duration_B" ]]; then ((differences++)); fi
    
    loudness_A=$(ffmpeg -hide_banner -nostats -i "$file_A" -af ebur128 -f null - 2>&1 | grep "Integrated loudness" -A 1 | tail -n 1 | awk '{print $2}')
    loudness_B=$(ffmpeg -hide_banner -nostats -i "$file_B" -af ebur128 -f null - 2>&1 | grep "Integrated loudness" -A 1 | tail -n 1 | awk '{print $2}')
    if [[ "$loudness_A" != "$loudness_B" ]]; then ((differences++)); fi

    size_A=$(stat -c %s "$file_A"); size_B=$(stat -c %s "$file_B")
    if [[ "$size_A" != "$size_B" ]]; then ((differences++)); fi

    ext_A="${file_A##*.}"; ext_B="${file_B##*.}"
    if [[ "$ext_A" != "$ext_B" ]]; then ((differences++)); fi

    bpm_calc_A=$(ffmpeg -i "$file_A" -ar 44100 -ac 1 -f f32le - 2>/dev/null | bpm)
    bpm_calc_B=$(ffmpeg -i "$file_B" -ar 44100 -ac 1 -f f32le - 2>/dev/null | bpm)
    if [[ "$bpm_calc_A" != "$bpm_calc_B" ]]; then ((differences++)); fi

    # --- 2. OBTENER Y COMPARAR ETIQUETAS LOCALES ---
    tags=("Artista" "Titulo" "Album" "Año" "Género" "AlbumArt" "NumPista" "NumDisco" "Compositor" "BPM")
    declare -A tags_A tags_B
    for tag in "${tags[@]}"; do
        tags_A[$tag]=$(get_local_tag "$file_A" "$tag")
        tags_B[$tag]=$(get_local_tag "$file_B" "$tag")
        if [[ "${tags_A[$tag]}" != "${tags_B[$tag]}" ]]; then
            ((differences++))
        fi
    done

    # --- 3. DECIDIR SI PREGUNTAR O AUTO-ELIMINAR ---
    mkdir -p "$DUPLICATES_DIR"
    if [ "$differences" -eq 0 ]; then
        echo "✅ Duplicados idénticos en metadatos. Moviendo automáticamente: '$file_B'"
        mv -v "$file_B" "$DUPLICATES_DIR/"
    else
        if [ "$AUTOMATIC_MODE" = false ]; then
            # Re-calculamos los colores solo cuando los necesitamos
            [[ "$bitrate_A" != "$bitrate_B" ]] && color_bitrate="$YELLOW" || color_bitrate="$NC"
            [[ "$duration_A" != "$duration_B" ]] && color_duration="$YELLOW" || color_duration="$NC"
            [[ "$loudness_A" != "$loudness_B" ]] && color_loudness="$YELLOW" || color_loudness="$NC"
            [[ "$size_A" != "$size_B" ]] && color_size="$YELLOW" || color_size="$NC"
            [[ "$ext_A" != "$ext_B" ]] && color_ext="$YELLOW" || color_ext="$NC"
            [[ "$bpm_calc_A" != "$bpm_calc_B" ]] && color_bpm_calc="$YELLOW" || color_bpm_calc="$NC"
            
            declare -A colors
            for tag in "${tags[@]}"; do
                [[ "${tags_A[$tag]}" != "${tags_B[$tag]}" ]] && colors[$tag]="$YELLOW" || colors[$tag]="$NC"
            done

            echo "🔬 Duplicados con $differences diferencia(s) encontradas. Se requiere acción manual."
            echo "   (A) Original:  '$file_A'"
            echo "   (B) Duplicado: '$file_B'"
            
            # IMPRIMIR TABLAS
            echo
            printf "%-25s | %s | %s\n" "MÉTRICA TÉCNICA" "$(format_cell 'ARCHIVO (A)' "$NC")" "$(format_cell 'ARCHIVO (B)' "$NC")"
            printf "========================================================================================================\n"
            printf "%-25s | %s | %s\n" "Bitrate (bps)" "$(format_cell "${bitrate_A:--}" "$color_bitrate")" "$(format_cell "${bitrate_B:--}" "$color_bitrate")"
            printf "%-25s | %s | %s\n" "Duración (s)" "$(format_cell "$duration_A" "$color_duration")" "$(format_cell "$duration_B" "$color_duration")"
            printf "%-25s | %s | %s\n" "Volumen (LUFS)" "$(format_cell "${loudness_A:--}" "$color_loudness")" "$(format_cell "${loudness_B:--}" "$color_loudness")"
            printf "%-25s | %s | %s\n" "Tamaño de archivo (bytes)" "$(format_cell "$size_A" "$color_size")" "$(format_cell "$size_B" "$color_size")"
            printf "%-25s | %s | %s\n" "Extensión de archivo" "$(format_cell "$ext_A" "$color_ext")" "$(format_cell "$ext_B" "$color_ext")"
            printf "%-25s | %s | %s\n" "BPM Calculado (Audio)" "$(format_cell "$(printf "%.1f" "${bpm_calc_A:-0.0}")" "$color_bpm_calc")" "$(format_cell "$(printf "%.1f" "${bpm_calc_B:-0.0}")" "$color_bpm_calc")"
            echo
            
            printf "%-15s | %-48s | %-48s\n" "ETIQUETA" "ARCHIVO (A)" "ARCHIVO (B)"
            printf "================================================================================================================\n"
            printf "%-15s | %s | %s\n" "Artista" "$(format_cell "${tags_A[Artista]}" "${colors[Artista]}")" "$(format_cell "${tags_B[Artista]}" "${colors[Artista]}")"
            printf "%-15s | %s | %s\n" "Título" "$(format_cell "${tags_A[Titulo]}" "${colors[Titulo]}")" "$(format_cell "${tags_B[Titulo]}" "${colors[Titulo]}")"
            printf "%-15s | %s | %s\n" "Álbum" "$(format_cell "${tags_A[Album]}" "${colors[Album]}")" "$(format_cell "${tags_B[Album]}" "${colors[Album]}")"
            printf "%-15s | %s | %s\n" "Año" "$(format_cell "${tags_A[Año]}" "${colors[Año]}")" "$(format_cell "${tags_B[Año]}" "${colors[Año]}")"
            printf "%-15s | %s | %s\n" "Género" "$(format_cell "${tags_A[Género]}" "${colors[Género]}")" "$(format_cell "${tags_B[Género]}" "${colors[Género]}")"
            printf "%-15s | %s | %s\n" "Carátula" "$(format_cell "${tags_A[AlbumArt]}" "${colors[AlbumArt]}")" "$(format_cell "${tags_B[AlbumArt]}" "${colors[AlbumArt]}")"
            printf "%-15s | %s | %s\n" "Nº Pista" "$(format_cell "${tags_A[NumPista]}" "${colors[NumPista]}")" "$(format_cell "${tags_B[NumPista]}" "${colors[NumPista]}")"
            printf "%-15s | %s | %s\n" "Nº Disco" "$(format_cell "${tags_A[NumDisco]}" "${colors[NumDisco]}")" "$(format_cell "${tags_B[NumDisco]}" "${colors[NumDisco]}")"
            printf "%-15s | %s | %s\n" "Compositor" "$(format_cell "${tags_A[Compositor]}" "${colors[Compositor]}")" "$(format_cell "${tags_B[Compositor]}" "${colors[Compositor]}")"
            printf "%-15s | %s | %s\n" "BPM (Etiqueta)" "$(format_cell "${tags_A[BPM]}" "${colors[BPM]}")" "$(format_cell "${tags_B[BPM]}" "${colors[BPM]}")"
            echo

            # DIÁLOGO INTERACTIVO
            while true; do
                read -p "Acción -> Conservar (A/B) | (S)altar | (D)etener: " choice
                case "${choice^^}" in
                    A) mv -v "$file_B" "$DUPLICATES_DIR/"; music_ids[$music_id_key]="$file_A"; break ;;
                    B) mv -v "$file_A" "$DUPLICATES_DIR/"; music_ids[$music_id_key]="$file_B"; break ;;
                    S) echo "⏭️ Saltando..."; break ;;
                    D) echo "🛑 Deteniendo el proceso."; exit 0 ;;
                    *) echo "❌ Opción no válida." ;;
                esac
            done
        else
            echo "⏭️ Diferencias encontradas en modo automático. Saltando par: '$file_A' y '$file_B'"
        fi
    fi
}


# ==============================================================================
# --- INICIO DEL SCRIPT PRINCIPAL ---
# ==============================================================================
echo "🎶 Iniciando Gestor Musical Interactivo v8.1..."
AUTOMATIC_MODE=false
read -p "¿Desea ejecutar solo el proceso automático? (S/N): " auto_choice
if [[ "${auto_choice^^}" == "S" ]]; then
    AUTOMATIC_MODE=true
    echo "⚙️ Modo automático activado."
else
    echo "👤 Modo manual activado."
fi
echo "================================================================================================================"

for file in *.mp3; do
    [ -f "$file" ] || continue
    
    # Verificación de archivo dañado
    error_output=$(ffprobe -v error -i "$file" -f null - 2>&1)
    if echo "$error_output" | grep -q "Invalid data found when processing input"; then
        echo -e "${RED}CORRUPTO:${NC} Moviendo a '$DAMAGED_DIR/': '$file'"
        mkdir -p "$DAMAGED_DIR"
        mv -v "$file" "$DAMAGED_DIR/"
        continue
    fi

    echo "🔎 Analizando: '$file'..."
    music_id=$(python3 "$PYTHON_RECOGNIZER" "$file")

    if [ -z "$music_id" ]; then
        echo "   ⚠️ No se pudo obtener ID de la canción. Saltando."
        continue
    fi

    if [[ -v music_ids[$music_id] ]]; then
        original_file="${music_ids[$music_id]}"
        if [ -f "$original_file" ]; then
            echo "🔥 ¡DUPLICADO PERCEPTUAL ENCONTRADO!"
            process_duplicate_pair "$original_file" "$file" "$music_id"
            echo "----------------------------------------------------------------------------------------------------------------"
        fi
    else
        music_ids[$music_id]="$file"
    fi
done
echo "✅ Búsqueda finalizada."
