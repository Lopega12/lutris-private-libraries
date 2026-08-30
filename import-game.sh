#!/usr/bin/env bash

TARGET_PATH="$1"
PROFILE="$2"

[ -z "$TARGET_PATH" ] && exit 1

# Exportar variables de pantalla para la GUI
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"

obtain_profile(){
local PROFILES_JSON="$HOME/.config/lutris-profiles.json"
local DIR_NAME
local BASE_DATA_DIR

# Extraer rutas desde el JSON si el perfil no es el por defecto ("Lutris")
if [ -n "$PROFILE" ] && [ "$PROFILE" != "Lutris" ] && [ -f "$PROFILES_JSON" ]; then
    # Leer la ruta base del JSON y expandir $HOME
    BASE_DATA_DIR=$(python3 -c "
import json, sys, os
try:
    with open('$PROFILES_JSON', 'r') as f:
        data = json.load(f)
    prof = sys.argv[1]
    for key, val in data.items():
        if key.lower() == prof.lower():
            # Expandir $HOME o ~ a la ruta real
            print(os.path.expanduser(os.path.expandvars(val)))
            break
except Exception:
    pass
" "$PROFILE")

    if [ -n "$BASE_DATA_DIR" ]; then
        # Extraer el sufijo del perfil (ej: 'lutris-private' o 'lutris-retro')
        DIR_NAME=$(basename "$BASE_DATA_DIR")

        export XDG_DATA_HOME="$BASE_DATA_DIR"
        export XDG_CONFIG_HOME="$HOME/.config/$DIR_NAME"
        export XDG_CACHE_HOME="$HOME/.cache/$DIR_NAME"
    fi
fi
}

executable_detection(){
local EXE_FILE
# Detección del ejecutable si se pasa una carpeta
if [ -d "$TARGET_PATH" ]; then
    EXE_FILE=$(find "$TARGET_PATH" -maxdepth 2 -type f -iname "*.exe" | head -n 1)
    [ -n "$EXE_FILE" ] && TARGET_PATH="$EXE_FILE"
fi
}

prepare_installer(){
local GAME_NAME
# Generación de nombres y slugs
GAME_NAME=$(basename "$(dirname "$TARGET_PATH")")
[ "$GAME_NAME" = "." ] || [ "$GAME_NAME" = "/" ] && GAME_NAME=$(basename "$TARGET_PATH" | sed -E 's/\.(exe|EXE)$//')

SLUG=$(echo "$GAME_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')
TMP_YAML="/tmp/lutris_${SLUG}.yml"

# Generar el YAML del instalador
cat <<EOF > "$TMP_YAML"
name: "${GAME_NAME}"
game_slug: "${SLUG}"
slug: "${SLUG}-installer"
version: "1.0 Local"
runner: wine

script:
  game:
    exe: "${TARGET_PATH}"
    prefix: "$HOME/.wine-games/proton-prefix"
EOF
}


main(){
obtain_profile
executable_detection
prepare_installer

# Lanzar Lutris inyectando el entorno asignado
if [ -n "$XDG_DATA_HOME" ] && [ -n "$XDG_CONFIG_HOME" ]; then
    env XDG_DATA_HOME="$XDG_DATA_HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" lutris -i "$TMP_YAML" &
else
    # Si es "Lutris" o no se especifica perfil, abre la biblioteca predeterminada
    lutris -i "$TMP_YAML" &
fi
}

main "$@"
