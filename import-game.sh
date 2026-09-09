#!/usr/bin/env bash

TARGET_PATH="$1"
PROFILE="$2"

[ -z "$TARGET_PATH" ] && exit 1

# Export display GUI vars
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"

obtain_profile(){
local PROFILES_JSON="$HOME/.config/lutris-profiles.json"
local DIR_NAME
local BASE_DATA_DIR

if [ -n "$PROFILE" ] && [ "$PROFILE" != "Lutris" ] && [ -f "$PROFILES_JSON" ]; then
       BASE_DATA_DIR=$(jq -r --arg profile "$PROFILE" '
        to_entries[]
        | select(.key | ascii_downcase == ($profile | ascii_downcase))
        | .value
        ' "$PROFILES_JSON")

        if [ -n "$BASE_DATA_DIR" ]; then
            DIR_NAME=$(basename "$BASE_DATA_DIR")

            export XDG_DATA_HOME="$BASE_DATA_DIR"
            export XDG_CONFIG_HOME="$HOME/.config/$DIR_NAME"
            export XDG_CACHE_HOME="$HOME/.cache/$DIR_NAME"
        fi
    fi
}

executable_detection(){
local EXE_FILE
# Launcher executable detection
if [ -d "$TARGET_PATH" ]; then
    EXE_FILE=$(find "$TARGET_PATH" -maxdepth 2 -type f -iname "*.exe" | head -n 1)
    [ -n "$EXE_FILE" ] && TARGET_PATH="$EXE_FILE"
fi
}

prepare_installer(){
local GAME_NAME
# Slugs/Names generator
GAME_NAME=$(basename "$(dirname "$TARGET_PATH")")
[ "$GAME_NAME" = "." ] || [ "$GAME_NAME" = "/" ] && GAME_NAME=$(basename "$TARGET_PATH" | sed -E 's/\.(exe|EXE)$//')

SLUG=$(echo "$GAME_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')
TMP_YAML="/tmp/lutris_${SLUG}.yml"

# YAML Install generator
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

# Inject Lutris launcher to assigment enviroment
if [ -n "$XDG_DATA_HOME" ] && [ -n "$XDG_CONFIG_HOME" ]; then
    env XDG_DATA_HOME="$XDG_DATA_HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" lutris -i "$TMP_YAML" &
else
    # If it is “Lutris” or no profile is specified, open the default library
    lutris -i "$TMP_YAML" &
fi
}

main "$@"
