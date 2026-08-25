#!/usr/bin/env bash

set -u

# ============================================================
# Eliminar biblioteca privada de Lutris
# ============================================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_JSON="$HOME/.config/lutris-profiles.json"
LIBRARY_BASE="$HOME/.local/share"
BIN_DIR="$HOME/.local/bin"

MAX_NAME_LENGTH=50

# ------------------------------------------------------------
# Colores
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Funciones
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Cabecera
# ------------------------------------------------------------

clear

echo
echo "========================================"
echo "    ELIMINAR BIBLIOTECA PRIVADA LUTRIS"
echo "========================================"
echo

echo "Este script eliminará una biblioteca privada"
echo "de Lutris y sus archivos asociados."
echo

# ------------------------------------------------------------
# Comprobaciones iniciales
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Obtener perfiles
# ------------------------------------------------------------

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

    if [[ "$PROFILE" == "Lutris" ]]; then
        echo "  $PROFILE"
        echo "    (biblioteca principal — no se puede eliminar)"
        echo
    else
        echo "  $PROFILE"
        echo "    $PATH_VALUE"
        echo
    fi

done

# ------------------------------------------------------------
# Nombre
# ------------------------------------------------------------

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

    if [[ "$LIBRARY_NAME" == "Lutris" ]]; then
        error "La biblioteca principal de Lutris no se puede eliminar."
        echo
        continue
    fi

    if [[ "$LIBRARY_NAME" == "Lutris" || "$LIBRARY_NAME" == "lutris" ]]; then
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

if [[ "$BASE_DATA_DIR" == "$LIBRARY_BASE/lutris" ]]; then
    error "La ruta corresponde a la instalación principal de Lutris."
    pause_exit
fi

# ------------------------------------------------------------
# Rutas asociadas
# ------------------------------------------------------------

CONFIG_DIR="$HOME/.config/$DIR_NAME"
CACHE_DIR="$HOME/.cache/$DIR_NAME"
LAUNCHER="$BIN_DIR/$DIR_NAME"

# ------------------------------------------------------------
# Resumen
# ------------------------------------------------------------

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

warning "Esta operación eliminará los datos de esta biblioteca."
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

# ------------------------------------------------------------
# Eliminar archivos
# ------------------------------------------------------------

echo "========================================"
echo "          ELIMINANDO BIBLIOTECA"
echo "========================================"
echo

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

# ------------------------------------------------------------
# Eliminar del JSON
# ------------------------------------------------------------

echo
info "Eliminando biblioteca de lutris-profiles.json..."

TMP_PROFILES="${PROFILES_JSON}.tmp"

if jq --arg name "$LIBRARY_NAME" \
      'del(.[$name])' \
      "$PROFILES_JSON" > "$TMP_PROFILES"; then

    if jq empty "$TMP_PROFILES" >/dev/null 2>&1; then
        mv -- "$TMP_PROFILES" "$PROFILES_JSON"
        success "Biblioteca eliminada del JSON."
    else
        rm -f -- "$TMP_PROFILES"
        error "El JSON resultante no es válido."
        exit 1
    fi

else

    rm -f -- "$TMP_PROFILES"
    error "No se pudo actualizar lutris-profiles.json."
    exit 1

fi

# ------------------------------------------------------------
# Regenerar menú contextual
# ------------------------------------------------------------

echo
info "Actualizando menú contextual de Lutris..."

UPDATE_MENU="$SCRIPT_DIR/update-contextual-menu.sh"

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

# ------------------------------------------------------------
# Comprobación final
# ------------------------------------------------------------

echo
echo "========================================"
echo "       COMPROBANDO LA ELIMINACIÓN"
echo "========================================"
echo

CHECK_OK=true

if [[ ! -e "$BASE_DATA_DIR" ]]; then
    success "Biblioteca eliminada"
else
    error "La biblioteca todavía existe."
    CHECK_OK=false
fi

if [[ ! -e "$CONFIG_DIR" ]]; then
    success "Configuración eliminada"
else
    error "La configuración todavía existe."
    CHECK_OK=false
fi

if [[ ! -e "$CACHE_DIR" ]]; then
    success "Caché eliminada"
else
    error "La caché todavía existe."
    CHECK_OK=false
fi

if [[ ! -e "$LAUNCHER" ]]; then
    success "Launcher eliminado"
else
    error "El launcher todavía existe."
    CHECK_OK=false
fi

if jq -e --arg name "$LIBRARY_NAME" \
    'has($name) | not' \
    "$PROFILES_JSON" >/dev/null 2>&1; then

    success "Perfil eliminado del JSON"

else

    error "El perfil todavía aparece en el JSON."
    CHECK_OK=false

fi

echo

if ! $CHECK_OK; then
    error "La eliminación no ha terminado correctamente."
    exit 1
fi

echo "========================================"
echo "   BIBLIOTECA ELIMINADA CORRECTAMENTE"
echo "========================================"
echo

success "Biblioteca: $LIBRARY_NAME"
echo
info "El menú contextual de KDE ha sido regenerado."
echo
