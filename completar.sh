#!/bin/bash

# ==============================================================================
# METACOMPLETOR v2.1 (Sintaxis de Pista/Disco Corregida)
#
# - Corregida la sintaxis de eyeD3 para versiones antiguas que no aceptan
#   el formato "N/T".
# - Ahora se usan los argumentos por separado: -n (track), -N (total tracks),
#   -d (disc), -D (total discs), según el manual de la versión del usuario.
#
# Requisitos: eyeD3, ffmpeg, bpm-tools, curl, jq
# ==============================================================================

# --- Colores y Dependencias ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_command() {
    command -v "$1" >/dev/null 2>&1 || { echo -e >&2 "${RED}❌ Error: El comando '$1' es necesario pero no está instalado.${NC}"; exit 1; }
}

check_command "eyeD3"; check_command "ffmpeg"; check_command "bpm"; check_command "curl"; check_command "jq"


# --- Función para obtener una etiqueta específica ---
get_local_tag() {
    local file="$1"; local tag_name="$2"; local result=""
    if [ ! -r "$file" ]; then echo "-"; return; fi
    case "$tag_name" in
        Artista)    result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^artist:" | sed 's/artist: *//' | tr -d '\0') ;;
        Titulo)     result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^title:" | sed 's/title: *//' | tr -d '\0') ;;
        Año)        result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^recording date:" | awk '{print $3}') ;;
        Album)      result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^album:" | sed -e 's/album: *//' -e 's/ (artist:.*)//') ;;
        BPM)        result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^BPM:" | awk '{print $2}') ;;
        Género)     result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^genre:" | sed -e 's/genre: *//' -e 's/ (id=[0-9]*)//' | tr -d '\0') ;;
        NumPista)   result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^track:" | awk '{print $2}') ;;
        NumDisco)   result=$(eyeD3 --no-color "$file" 2>/dev/null | grep -a "^disc:" | awk '{print $2}') ;;
        AlbumArt)
            local count=$(eyeD3 --no-color "$file" 2>/dev/null | grep -c "Image:")
            if [[ $count -gt 0 ]]; then result="Sí"; else result="No"; fi ;;
        *)          result="" ;;
    esac
    echo "${result:--}"
}

# ==============================================================================
# --- INICIO DEL SCRIPT PRINCIPAL ---
# ==============================================================================
echo -e "🎶 ${CYAN}Iniciando MetaCompletor v2.1...${NC}"
echo "========================================================================"

for file in *.mp3; do
    [ -f "$file" ] || continue
    echo -e "\n🔎 Procesando archivo: ${YELLOW}$file${NC}"
    MODIFIED=false
    eyeD3 --remove-frame TIPL --remove-frame TMCL "$file" >/dev/null 2>&1

    # --- 1. COMPLETAR BPM (si falta) ---
    if [[ "$(get_local_tag "$file" "BPM")" == "-" ]]; then
        echo "   - Etiqueta BPM no encontrada. Calculando..."
        bpm_calc=$(ffmpeg -i "$file" -ar 44100 -ac 1 -f f32le - 2>/dev/null | bpm)
        if [[ "$bpm_calc" =~ ^[0-9.]+$ && "$bpm_calc" != "0.0" ]]; then
            bpm_int=$(printf "%.0f" "$bpm_calc")
            eyeD3 --to-v2.3 --bpm "$bpm_int" "$file" >/dev/null
            if [[ "$(get_local_tag "$file" "BPM")" != "-" ]]; then
                echo -e "   ${GREEN}✓ BPM actualizado a: $bpm_int${NC}"; MODIFIED=true
            fi
        fi
    fi

    # --- 2. COMPLETAR METADATOS DESDE MUSICBRAINZ ---
    has_art=$(get_local_tag "$file" "AlbumArt"); has_album=$(get_local_tag "$file" "Album"); has_year=$(get_local_tag "$file" "Año")
    has_genre=$(get_local_tag "$file" "Género"); has_track_num=$(get_local_tag "$file" "NumPista"); has_disc_num=$(get_local_tag "$file" "NumDisco")

    if [[ "$has_art" == "No" || "$has_album" == "-" || "$has_year" == "-" || "$has_genre" == "-" || "$has_track_num" == "-" ]]; then
        artist=$(get_local_tag "$file" "Artista"); title=$(get_local_tag "$file" "Titulo")
        if [[ "$artist" == "-" || "$title" == "-" ]]; then
            echo -e "   ${YELLOW}⚠️  Saltando búsqueda online: falta Artista o Título.${NC}"
        else
            echo "   - Buscando datos faltantes en MusicBrainz..."
            encoded_artist=$(echo "$artist" | jq -sRr @uri); encoded_title=$(echo "$title" | jq -sRr @uri)
            api_url="https://musicbrainz.org/ws/2/recording/?query=artist:${encoded_artist}%20AND%20recording:${encoded_title}&fmt=json&limit=1"
            response=$(curl -s -A "MetaCompletor/2.1 ( mi@email.com )" "$api_url")
            first_release=$(echo "$response" | jq -r '.recordings[0].releases[0]')

            if [[ -n "$first_release" && "$first_release" != "null" ]]; then
                # === COMPLETAR AÑO (si falta) ===
                if [[ "$has_year" == "-" ]]; then
                    year=$(echo "$first_release" | jq -r '.date' | cut -d'-' -f1)
                    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
                        eyeD3 --to-v2.3 -Y "$year" "$file" >/dev/null; MODIFIED=true; echo -e "   ${GREEN}✓ Año actualizado a: $year${NC}"
                    fi
                fi
                # === COMPLETAR ÁLBUM (si falta) ===
                if [[ "$has_album" == "-" ]]; then
                    album=$(echo "$first_release" | jq -r '.title')
                    if [[ -n "$album" && "$album" != "null" ]]; then
                        eyeD3 --to-v2.3 --album "$album" "$file" >/dev/null; MODIFIED=true; echo -e "   ${GREEN}✓ Álbum actualizado a: $album${NC}"
                    fi
                fi
                
                # === SINTAXIS CORREGIDA PARA PISTA Y DISCO ===
                if [[ "$has_track_num" == "-" ]]; then
                    track_offset=$(echo "$first_release" | jq -r '.media[0]."track-offset"'); track_total=$(echo "$first_release" | jq -r '.media[0]."track-count"')
                    if [[ "$track_offset" =~ ^[0-9]+$ && "$track_total" =~ ^[0-9]+$ ]]; then
                        track_num=$((track_offset + 1))
                        # Usamos -n para el número y -N para el total, como indica el manual de eyeD3
                        eyeD3 --to-v2.3 -n "$track_num" -N "$track_total" "$file" >/dev/null
                        MODIFIED=true; echo -e "   ${GREEN}✓ N.º de Pista actualizado a: $track_num/$track_total${NC}"
                    fi
                fi
                if [[ "$has_disc_num" == "-" ]]; then
                    disc_num=$(echo "$first_release" | jq -r '.media[0].position'); disc_total=$(echo "$first_release" | jq -r '."media-count"')
                    if [[ "$disc_num" =~ ^[0-9]+$ && "$disc_total" =~ ^[0-9]+$ ]]; then
                        # Usamos -d para el número y -D para el total
                        eyeD3 --to-v2.3 -d "$disc_num" -D "$disc_total" "$file" >/dev/null
                        MODIFIED=true; echo -e "   ${GREEN}✓ N.º de Disco actualizado a: $disc_num/$disc_total${NC}"
                    fi
                fi

                # === COMPLETAR GÉNERO (si falta) ===
                if [[ "$has_genre" == "-" ]]; then
                    release_group_id=$(echo "$first_release" | jq -r '."release-group".id')
                    if [[ -n "$release_group_id" && "$release_group_id" != "null" ]]; then
                        echo "   - Buscando género para el álbum..."; sleep 1
                        genre_url="https://musicbrainz.org/ws/2/release-group/${release_group_id}?inc=tags&fmt=json"
                        genre_response=$(curl -s -A "MetaCompletor/2.1 ( mi@email.com )" "$genre_url")
                        genre=$(echo "$genre_response" | jq -r '.tags | sort_by(-.count)[0].name' | sed -e "s/\b\(.\)/\u\1/g")
                        if [[ -n "$genre" && "$genre" != "null" && "$genre" != "Null" ]]; then
                            eyeD3 --to-v2.3 --genre="$genre" "$file" >/dev/null
                            MODIFIED=true; echo -e "   ${GREEN}✓ Género actualizado a: $genre${NC}"
                        else
                            echo -e "   ${YELLOW}✗ No se encontró género para este álbum.${NC}"
                        fi
                    fi
                fi

                # === COMPLETAR CARÁTULA (si falta) ===
                if [[ "$has_art" == "No" ]]; then
                    release_id=$(echo "$first_release" | jq -r '.id')
                    if [[ -n "$release_id" && "$release_id" != "null" ]]; then
                        echo "   - Buscando carátula en CoverArt Archive..."; sleep 1
                        cover_url="http://coverartarchive.org/release/${release_id}/front"
                        if curl -L -f -o "cover.jpg" "$cover_url" 2>/dev/null; then
                            eyeD3 --to-v2.3 --add-image "cover.jpg:FRONT_COVER" "$file" >/dev/null
                            MODIFIED=true; echo -e "   ${GREEN}✓ Carátula añadida correctamente.${NC}"; rm "cover.jpg"
                        else
                            echo -e "   ${YELLOW}✗ No se encontró carátula en CoverArt Archive.${NC}"
                        fi
                    fi
                fi
            else
                echo -e "   ${RED}✗ No se encontraron resultados en MusicBrainz.${NC}"
            fi
            sleep 1
        fi
    fi

    if [ "$MODIFIED" = false ]; then
        echo "   ✨ El archivo ya tiene los datos necesarios. No se realizaron cambios."
    fi
done

echo -e "\n${CYAN}✅ Proceso finalizado.${NC}"
