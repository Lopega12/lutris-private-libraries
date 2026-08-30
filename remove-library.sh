#!/usr/bin/env bash

set -eu

# ============================================================
# Eliminar biblioteca privada de Lutris
# ============================================================
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
    read -rp "Pulsa Enter para salir..."
    exit 1
}

disclaimer(){

clear

echo
echo "========================================"
echo "    ELIMINAR BIBLIOTECA PRIVADA LUTRIS"
echo "========================================"
echo

echo "Este script eliminará una biblioteca privada"
echo "de Lutris y sus archivos asociados."
echo
}


check_environment(){

echo "========================================"
echo "       COMPROBANDO EL ENTORNO"
echo "========================================"
echo

if [[ ! -f "$PROFILES_JSON" ]]; then
    error "No existe el fichero de perfiles:"
    echo "  $PROFILES_JSON"
    pause_exit
fi

success "Fichero de perfiles encontrado."

if ! command -v jq >/dev/null 2>&1; then
    error "No se ha encontrado jq."
    pause_exit
fi

success "jq encontrado."

# Comprobar que el JSON es válido
if ! jq empty "$PROFILES_JSON" >/dev/null 2>&1; then
    error "El fichero lutris-profiles.json no es un JSON válido."
    echo
    echo "Corrige primero:"
    echo "  $PROFILES_JSON"
    pause_exit
fi

success "JSON válido."

echo
}

get_libraries(){
# ------------------------------------------------------------
# Obtener perfiles
# ------------------------------------------------------------
local -a PROFILES
local PROFILE
local PATH_VALUE

mapfile -t PROFILES < <(jq -r 'keys[]' "$PROFILES_JSON")

if (( ${#PROFILES[@]} == 0 )); then
    error "No hay bibliotecas registradas."
    pause_exit
fi

# ------------------------------------------------------------
# Mostrar bibliotecas
# ------------------------------------------------------------

echo "========================================"
echo "        BIBLIOTECAS DISPONIBLES"
echo "========================================"
echo

for PROFILE in "${PROFILES[@]}"; do

    PATH_VALUE=$(jq -r --arg name "$PROFILE" '.[$name]' "$PROFILES_JSON")

    if [[ "${PROFILE,,}" == "$MAIN_LIBRARY" ]]; then
        echo "  $PROFILE"
        echo "    (biblioteca principal — no se puede eliminar)"
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
echo "       BIBLIOTECA A ELIMINAR"
echo "========================================"
echo

while true; do

    read -rp "Nombre de la biblioteca: " LIBRARY_NAME

    LIBRARY_NAME="${LIBRARY_NAME#"${LIBRARY_NAME%%[![:space:]]*}"}"
    LIBRARY_NAME="${LIBRARY_NAME%"${LIBRARY_NAME##*[![:space:]]}"}"

    if [[ -z "$LIBRARY_NAME" ]]; then
        error "El nombre no puede estar vacío."
        echo
        continue
    fi

    if [[ "${LIBRARY_NAME,,}" == "$MAIN_LIBRARY" ]]; then
        error "La biblioteca principal de Lutris no se puede eliminar."
        echo
        continue
    fi

    # Comprobar que existe exactamente ese perfil
    if ! jq -e --arg name "$LIBRARY_NAME" \
        'has($name)' "$PROFILES_JSON" >/dev/null 2>&1; then

        error "No existe una biblioteca con ese nombre:"
        echo "  $LIBRARY_NAME"
        echo
        continue
    fi

    break
done
}

validate_library(){
# ------------------------------------------------------------
# Obtener ruta desde JSON
# ------------------------------------------------------------

BASE_DATA_DIR=$(jq -r \
    --arg name "$LIBRARY_NAME" \
    '.[$name]' \
    "$PROFILES_JSON")

BASE_DATA_DIR=$(printf '%s' "$BASE_DATA_DIR" \
    | sed "s|^\\\$HOME|$HOME|")

if [[ -z "$BASE_DATA_DIR" || "$BASE_DATA_DIR" == "null" ]]; then
    error "No se ha podido obtener la ruta de la biblioteca."
    pause_exit
fi

# ------------------------------------------------------------
# Validación de seguridad de la ruta
# ------------------------------------------------------------

DIR_NAME=$(basename "$BASE_DATA_DIR")

if [[ ! "$DIR_NAME" =~ ^lutris-[a-z0-9_-]+$ ]]; then
    error "La ruta de la biblioteca no tiene un formato válido:"
    echo "  $BASE_DATA_DIR"
    echo
    error "Por seguridad, no se eliminará nada."
    pause_exit
fi

if [[ "$BASE_DATA_DIR" != "$LIBRARY_BASE/lutris-"* ]]; then
    error "La biblioteca está fuera del directorio permitido:"
    echo "  $BASE_DATA_DIR"
    echo
    error "Por seguridad, no se eliminará nada."
    pause_exit
fi

#if [[ "$BASE_DATA_DIR" == "$LIBRARY_BASE/lutris" ]]; then
 #   error "La ruta corresponde a la instalación principal de Lutris."
  #  pause_exit
#fi

}



summary(){
# ------------------------------------------------------------
# Resumen
# ------------------------------------------------------------
local CONFIRM

echo
echo "========================================"
echo "               RESUMEN"
echo "========================================"
echo

echo "Biblioteca:"
echo "  $LIBRARY_NAME"
echo

echo "Datos:"
echo "  $BASE_DATA_DIR"
echo

echo "Configuración:"
echo "  $CONFIG_DIR"
echo

echo "Caché:"
echo "  $CACHE_DIR"
echo

echo "Launcher:"
echo "  $LAUNCHER"
echo

warning "Esta operación eliminará la biblioteca y todos sus archivos asociados."
warning "Esta operación no se puede deshacer."
echo

read -rp "¿Eliminar esta biblioteca? [s/N]: " CONFIRM

case "${CONFIRM,,}" in
    s|si|sí|y|yes)
        ;;
    *)
        echo
        info "Operación cancelada."
        exit 0
        ;;
esac

echo
}



drop_library(){
#------------------------------------------------------------
# Eliminar archivos
# ------------------------------------------------------------

echo "========================================"
echo "          ELIMINANDO BIBLIOTECA"
echo "========================================"
echo
    drop_library_files
}

drop_library_files(){

if [[ -e "$BASE_DATA_DIR" || -L "$BASE_DATA_DIR" ]]; then
    rm -rf -- "$BASE_DATA_DIR"
    success "Biblioteca eliminada."
else
    warning "La biblioteca no existe físicamente."
fi

if [[ -e "$CONFIG_DIR" || -L "$CONFIG_DIR" ]]; then
    rm -rf -- "$CONFIG_DIR"
    success "Configuración eliminada."
else
    info "Configuración no encontrada."
fi

if [[ -e "$CACHE_DIR" || -L "$CACHE_DIR" ]]; then
    rm -rf -- "$CACHE_DIR"
    success "Caché eliminada."
else
    info "Caché no encontrada."
fi

if [[ -e "$LAUNCHER" || -L "$LAUNCHER" ]]; then
    rm -f -- "$LAUNCHER"
    success "Launcher eliminado."
else
    info "Launcher no encontrado."
fi


}

unregistry_library_profile(){
echo
info "Eliminando biblioteca de lutris-profiles.json..."

local TMP_PROFILES="${PROFILES_JSON}.tmp"

jq --arg name "$LIBRARY_NAME" \
      'del(.[$name])' \
      "$PROFILES_JSON" > "$TMP_PROFILES"

    if jq empty "$TMP_PROFILES" >/dev/null 2>&1; then
        mv -- "$TMP_PROFILES" "$PROFILES_JSON"
        if jq -e --arg name "$LIBRARY_NAME" \
            'has($name) | not' \
            "$PROFILES_JSON" >/dev/null 2>&1; then
            success "Biblioteca eliminada del JSON."
        else
            error "La biblioteca todavía aparece en el JSON."
            return 1
        fi
    else
        rm -f -- "$TMP_PROFILES"
        error "JSON resultante no es válido."
        return 1
    fi



}


regenerate_contextual_menu(){
echo
info "Actualizando menú contextual de Lutris..."

local UPDATE_MENU="$SCRIPT_DIR/update-contextual-menu.sh"

if [[ -x "$UPDATE_MENU" ]]; then

    if "$UPDATE_MENU"; then
        success "Menú contextual actualizado."
    else
        warning "No se pudo actualizar automáticamente el menú contextual."
    fi

else

    warning "No se encontró:"
    echo "  $UPDATE_MENU"

fi
}


verify_library_removed(){
# ------------------------------------------------------------
# Comprobación final
# ------------------------------------------------------------

echo
echo "========================================"
echo "       COMPROBANDO LA ELIMINACIÓN"
echo "========================================"
echo
local check_ok=0

if [[ ! -e "$BASE_DATA_DIR" && ! -L "$BASE_DATA_DIR" ]]; then
    success "Biblioteca eliminada"
else
    error "La biblioteca todavía existe."
    check_ok=1
fi

if [[ ! -e "$CONFIG_DIR" && ! -L "$CONFIG_DIR" ]]; then
    success "Configuración eliminada"
else
    error "La configuración todavía existe."
    check_ok=1
fi

if [[ ! -e "$CACHE_DIR" && ! -L "$CACHE_DIR" ]]; then
    success "Caché eliminada"
else
    error "La caché todavía existe."
    check_ok=1
fi

if [[ ! -e "$LAUNCHER" && ! -L "$LAUNCHER" ]]; then
    success "Launcher eliminado"
else
    error "El launcher todavía existe."
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
# Rutas asociadas biblioteca lutris
# ------------------------------------------------------------

CONFIG_DIR="$HOME/.config/$DIR_NAME"
CACHE_DIR="$HOME/.cache/$DIR_NAME"
LAUNCHER="$BIN_DIR/$DIR_NAME"
summary
drop_library
if ! verify_library_removed; then
    error "La eliminación no ha terminado correctamente."
    exit 1
fi
if ! unregistry_library_profile; then
    error "No se pudo actualizar el perfil de la biblioteca."
    exit 1
fi
regenerate_contextual_menu


echo "========================================"
echo "   BIBLIOTECA ELIMINADA CORRECTAMENTE"
echo "========================================"
echo

success "Biblioteca: $LIBRARY_NAME"
echo
info "El menú contextual de KDE ha sido regenerado."
echo

}

main
