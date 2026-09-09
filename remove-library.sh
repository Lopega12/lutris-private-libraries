#!/usr/bin/env bash

set -eu

MAIN_LIBRARY="lutris"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_JSON="$HOME/.config/lutris-profiles.json"
LIBRARY_BASE="$HOME/.local/share"
BIN_DIR="$HOME/.local/bin"


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'


error() {
    echo -e "${RED}✗ $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${CYAN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

pause_exit() {
    echo
    read -rp "Press Enter to exit..."
    exit 1
}

disclaimer(){

clear

echo
echo "========================================"
echo "    REMOVE PRIVATE LUTRIS LIBRARY"
echo "========================================"
echo

echo "This script will remove a private Lutris library"
echo "and its associated files."
echo
}


check_environment(){

echo "========================================"
echo "       CHECKING ENVIRONMENT"
echo "========================================"
echo

if [[ ! -f "$PROFILES_JSON" ]]; then
    error "Profile file does not exist:"
    echo "  $PROFILES_JSON"
    pause_exit
fi

success "Profile file found."

if ! command -v jq >/dev/null 2>&1; then
    error "jq was not found."
    pause_exit
fi

success "jq found.."

if ! jq empty "$PROFILES_JSON" >/dev/null 2>&1; then
    error "The lutris-profiles.json file is not valid JSON."
    echo
    echo "Fix the following file first:"
    echo "  $PROFILES_JSON"
    pause_exit
fi

success "Valid JSON."

echo
}

get_libraries(){
# ------------------------------------------------------------
# Get profiles
# ------------------------------------------------------------
local -a PROFILES
local PROFILE
local PATH_VALUE

mapfile -t PROFILES < <(jq -r 'keys[]' "$PROFILES_JSON")

if (( ${#PROFILES[@]} == 0 )); then
    error "No libraries are registered."
    pause_exit
fi

echo "========================================"
echo "       AVAILABLE LIBRARIES"
echo "========================================"
echo

for PROFILE in "${PROFILES[@]}"; do

    PATH_VALUE=$(jq -r --arg name "$PROFILE" '.[$name]' "$PROFILES_JSON")

    if [[ "${PROFILE,,}" == "$MAIN_LIBRARY" ]]; then
        echo "  $PROFILE"
        echo "    (main library — cannot be removed)"
        echo
    else
        echo "  $PROFILE"
        echo "    $PATH_VALUE"
        echo
    fi

done
}

choose_library(){

echo "========================================"
echo "      LIBRARY TO REMOVE"
echo "========================================"
echo

while true; do

    read -rp "Library name: " LIBRARY_NAME

    LIBRARY_NAME="${LIBRARY_NAME#"${LIBRARY_NAME%%[![:space:]]*}"}"
    LIBRARY_NAME="${LIBRARY_NAME%"${LIBRARY_NAME##*[![:space:]]}"}"

    if [[ -z "$LIBRARY_NAME" ]]; then
        error "The name cannot be empty."
        echo
        continue
    fi

    if [[ "${LIBRARY_NAME,,}" == "$MAIN_LIBRARY" ]]; then
        error "The main Lutris library cannot be removed."
        echo
        continue
    fi

    # Check that the exact profile exists
    if ! jq -e --arg name "$LIBRARY_NAME" \
        'has($name)' "$PROFILES_JSON" >/dev/null 2>&1; then

        error "No library with that name exists:"
        echo "  $LIBRARY_NAME"
        echo
        continue
    fi

    break
done
}

validate_library(){
# ------------------------------------------------------------
# Get path from JSON
# ------------------------------------------------------------

BASE_DATA_DIR=$(jq -r \
    --arg name "$LIBRARY_NAME" \
    '.[$name]' \
    "$PROFILES_JSON")

BASE_DATA_DIR=$(printf '%s' "$BASE_DATA_DIR" \
    | sed "s|^\\\$HOME|$HOME|")

if [[ -z "$BASE_DATA_DIR" || "$BASE_DATA_DIR" == "null" ]]; then
    error "Could not determine the library path.."
    pause_exit
fi

# ------------------------------------------------------------
# Path security validation
# ------------------------------------------------------------

DIR_NAME=$(basename "$BASE_DATA_DIR")

if [[ ! "$DIR_NAME" =~ ^lutris-[a-z0-9_-]+$ ]]; then
    error "The library path does not have a valid format:"
    echo "  $BASE_DATA_DIR"
    echo
    error "For safety, nothing will be removed."
    pause_exit
fi

if [[ "$BASE_DATA_DIR" != "$LIBRARY_BASE/lutris-"* ]]; then
    error "The library is outside the allowed directory:"
    echo "  $BASE_DATA_DIR"
    echo
    error "For safety, nothing will be removed."
    pause_exit
fi

}



summary(){
local CONFIRM

echo
echo "========================================"
echo "               SUMMARY"
echo "========================================"
echo

echo "Library:"
echo "  $LIBRARY_NAME"
echo

echo "Data:"
echo "  $BASE_DATA_DIR"
echo

echo "Configuration:"
echo "  $CONFIG_DIR"
echo

echo "Cache:"
echo "  $CACHE_DIR"
echo

echo "Launcher:"
echo "  $LAUNCHER"
echo

warning "This operation will remove the library and all its associated files."
warning "This operation cannot be undone."
echo

read -rp "Remove this library? [y/N]: " CONFIRM

case "${CONFIRM,,}" in
    s|si|sí|y|yes)
        ;;
    *)
        echo
        info "Operation cancelled."
        exit 0
        ;;
esac

echo
}



drop_library(){

echo "========================================"
echo "          REMOVING LIBRARY"
echo "========================================"
echo
    drop_library_files
}

drop_library_files(){

if [[ -e "$BASE_DATA_DIR" || -L "$BASE_DATA_DIR" ]]; then
    rm -rf -- "$BASE_DATA_DIR"
    success "Library removed."
else
    warning "The library does not exist on disk."
fi

if [[ -e "$CONFIG_DIR" || -L "$CONFIG_DIR" ]]; then
    rm -rf -- "$CONFIG_DIR"
    success "Configuration removed."
else
    info "Configuration not found."
fi

if [[ -e "$CACHE_DIR" || -L "$CACHE_DIR" ]]; then
    rm -rf -- "$CACHE_DIR"
    success "Cache removed."
else
    info "Cache not found."
fi

if [[ -e "$LAUNCHER" || -L "$LAUNCHER" ]]; then
    rm -f -- "$LAUNCHER"
    success "Launcher removed."
else
    info "Launcher not found."
fi


}

unregistry_library_profile(){
echo
info "Removing library from lutris-profiles.json..."

local TMP_PROFILES="${PROFILES_JSON}.tmp"

jq --arg name "$LIBRARY_NAME" \
      'del(.[$name])' \
      "$PROFILES_JSON" > "$TMP_PROFILES"

    if jq empty "$TMP_PROFILES" >/dev/null 2>&1; then
        mv -- "$TMP_PROFILES" "$PROFILES_JSON"
        if jq -e --arg name "$LIBRARY_NAME" \
            'has($name) | not' \
            "$PROFILES_JSON" >/dev/null 2>&1; then
            success "Library removed from JSON."
        else
            error "The library is still present in the JSON."
            return 1
        fi
    else
        rm -f -- "$TMP_PROFILES"
        error "The resulting JSON is not valid."
        return 1
    fi



}


regenerate_contextual_menu(){
echo
info "Updating Lutris context menu..."

local UPDATE_MENU="$SCRIPT_DIR/update-contextual-menu.sh"

if [[ -x "$UPDATE_MENU" ]]; then

    if "$UPDATE_MENU"; then
        success "Context menu updated."
    else
        warning "The context menu could not be updated automatically."
    fi

else

    warning "Not found:"
    echo "  $UPDATE_MENU"

fi
}


verify_library_removed(){

echo
echo "========================================"
echo "       VERIFYING REMOVAL"
echo "========================================"
echo
local check_ok=0

if [[ ! -e "$BASE_DATA_DIR" && ! -L "$BASE_DATA_DIR" ]]; then
    success "Library removed."
else
    error "The library still exists."
    check_ok=1
fi

if [[ ! -e "$CONFIG_DIR" && ! -L "$CONFIG_DIR" ]]; then
    success "Configuration removed."
else
    error "The configuration still exists."
    check_ok=1
fi

if [[ ! -e "$CACHE_DIR" && ! -L "$CACHE_DIR" ]]; then
    success "Cache removed."
else
    error "The cache still exists."
    check_ok=1
fi

if [[ ! -e "$LAUNCHER" && ! -L "$LAUNCHER" ]]; then
    success "Launcher removed."
else
    error "The launcher still exists."
    check_ok=1
fi

return "$check_ok"


}

main(){

disclaimer
check_environment
get_libraries
choose_library
validate_library
# ------------------------------------------------------------
# Paths associated with the Lutris library
# ------------------------------------------------------------

CONFIG_DIR="$HOME/.config/$DIR_NAME"
CACHE_DIR="$HOME/.cache/$DIR_NAME"
LAUNCHER="$BIN_DIR/$DIR_NAME"
summary
drop_library
if ! verify_library_removed; then
    error "The deletion did not complete successfully."
    exit 1
fi
if ! unregistry_library_profile; then
    error "The library profile could not be updated."
    exit 1
fi
regenerate_contextual_menu


echo "========================================"
echo "   LIBRARY REMOVED SUCCESSFULLY"
echo "========================================"
echo

success "Library: $LIBRARY_NAME"
echo
info "The KDE context menu has been regenerated."
echo

}

main
