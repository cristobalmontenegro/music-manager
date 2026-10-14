# 🎵 Music Manager

**ES:** Suite de scripts en Bash para descargar, organizar, renombrar y depurar tu biblioteca musical local (MP3) desde Spotify y archivos sueltos. Todo funciona desde un menú interactivo en la terminal.

**EN:** A suite of Bash scripts to download, organize, rename and clean up your local music library (MP3) from Spotify and loose files. Everything runs from an interactive terminal menu.

---

## 🇪🇸 Español

### ¿Qué incluye?

| Script | Descripción |
|:---|:---|
| `menu.sh` | Menú principal que lanza de forma centralizada todas las herramientas. |
| `check_spotdl.sh` | Verifica e instala las dependencias necesarias para `spotdl` (Python, pip, ffmpeg). |
| `configurar_spotdl.sh` | Configura tus propias credenciales de Spotify para evitar los *Rate Limits* de las credenciales compartidas de `spotdl`. |
| `descargar.sh` | Descarga canciones, álbumes o playlists de Spotify con `spotdl`. |
| `organizador.sh` | Organiza la biblioteca MP3 en carpetas por artista/álbum usando las etiquetas ID3. |
| `renombrar.sh` | Renombra los MP3 al formato `Artista - Título.mp3` leyendo sus etiquetas ID3. |
| `completar.sh` | «Metacompletador»: completa etiquetas faltantes, carátulas, año, BPM, etc. |
| `comparadorsmart.sh` | Detección perceptual de audio (Chromaprint) para encontrar **duplicados reales** y elegir cuál conservar según su calidad. |
| `reconocedor.py` | Ayudante en Python que identifica cada pista por huella acústica con AcoustID. |
| `orgdebug.sh` | Utilidad de depuración que muestra la salida cruda de `eyeD3` de un archivo. |

### 🛠 Requisitos

- **Bash** (Linux/macOS; en Windows vía WSL o Git Bash)
- **Python 3** + `spotdl`
- `ffmpeg`
- `eyeD3` (etiquetas ID3)
- `bpm-tools` (comando `bpm`)
- `libchromaprint-tools` (comando `fpcalc`)
- `curl` y `jq`
- `pyacoustid` (para `reconocedor.py`)

### 🚀 Cómo empezar

```bash
chmod +x *.sh
./menu.sh
```

1. Desde el menú, usa **Verificar/Instalar spotdl** la primera vez.
2. (Opcional) Configura tus credenciales de Spotify con **Configurar credenciales** si ves errores de *Rate Limit*.
3. Descarga y luego organiza tu biblioteca.

---

## 🇬🇧 English

### What's included?

| Script | Description |
|:---|:---|
| `menu.sh` | Main menu that launches every tool from one place. |
| `check_spotdl.sh` | Checks and installs the dependencies required by `spotdl` (Python, pip, ffmpeg). |
| `configurar_spotdl.sh` | Configures your own Spotify credentials to avoid the *Rate Limits* of the shared ones. |
| `descargar.sh` | Downloads songs, albums or playlists from Spotify using `spotdl`. |
| `organizador.sh` | Organizes the MP3 library into artist/album folders using ID3 tags. |
| `renombrar.sh` | Renames MP3s to `Artist - Title.mp3` from their ID3 tags. |
| `completar.sh` | "Metacompleter": fills in missing tags, cover art, year, BPM, etc. |
| `comparadorsmart.sh` | Perceptual audio matching (Chromaprint) to find **true duplicates** and pick the best-quality copy. |
| `reconocedor.py` | Python helper that identifies each track by acoustic fingerprint with AcoustID. |
| `orgdebug.sh` | Debug utility that prints the raw `eyeD3` output of a file. |

### 🛠 Requirements

- **Bash** (Linux/macOS; on Windows via WSL or Git Bash)
- **Python 3** + `spotdl`
- `ffmpeg`
- `eyeD3`
- `bpm-tools` (the `bpm` command)
- `libchromaprint-tools` (the `fpcalc` command)
- `curl` and `jq`
- `pyacoustid` (for `reconocedor.py`)

### 🚀 Getting started

```bash
chmod +x *.sh
./menu.sh
```

1. Use **Check/Install spotdl** the first time.
2. (Optional) Set your own Spotify credentials if you hit *Rate Limit* errors.
3. Download, then organize your library.

---

## ☕ Apóyame / Support me

**ES:** Si esta herramienta te resultó útil, puedes invitarme un café. ¡Gracias!
**EN:** If this tool was useful, you can buy me a coffee. Thanks!

<a href="https://ko-fi.com/cristobalmontenegro" target="_blank">
  <img height="36" style="border:0px;height:36px;" src="https://storage.ko-fi.com/cdn/kofi6.png?v=6" border="0" alt="Buy Me a Coffee at ko-fi.com" />
</a>

## 📄 Licencia / License

**ES:** Publicado bajo la licencia MIT. **EN:** Released under the MIT License.
