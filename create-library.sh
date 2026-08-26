#!/usr/bin/env bash

set -u

# ============================================================
# Crear biblioteca privada de Lutris
# ============================================================
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_JSON="$HOME/.config/lutris-profiles.json"
LIBRARY_BASE="$HOME/.local/share"
NORMAL_LUTRIS="$HOME/.local/share/lutris"
BIN_DIR="$HOME/.local/bin"

# Fichero oculto donde se almacena el SHA-256 del PIN
HASH_FILE=".access"

MAX_NAME_LENGTH=50
MIN_PIN_LENGTH=4
MAX_PIN_LENGTH=8

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

check_profiles_file(){
if [[ ! -f "$PROFILES_JSON" ]]; then

    info "No existe lutris-profiles.json. Creando..."

    mkdir -p "$(dirname "$PROFILES_JSON")"

    cat > "$PROFILES_JSON" <<EOF
{
  "Lutris": "\$HOME/.local/share/lutris"
}
EOF

    if [[ ! -f "$PROFILES_JSON" ]]; then
        error "No se pudo crear lutris-profiles.json."
        pause_exit
    fi

    success "lutris-profiles.json creado."

fi

if ! jq empty "$PROFILES_JSON" >/dev/null 2>&1; then
    error "El fichero lutris-profiles.json no es un JSON válido."
    echo
    echo "Corrige primero:"
    echo "  $PROFILES_JSON"
    pause_exit
fi

success "lutris-profiles.json es válido."

if ! jq -e 'type == "object"' "$PROFILES_JSON" >/dev/null 2>&1; then
    error "lutris-profiles.json no contiene un objeto JSON válido."
    pause_exit
fi

success "Estructura del fichero de perfiles válida."

}

check_dependences(){
if ! command -v lutris >/dev/null 2>&1; then
    error "No se ha encontrado Lutris en el sistema."
    pause_exit
fi

success "Lutris encontrado: $(command -v lutris)"


if ! command -v jq >/dev/null 2>&1; then
    error "No se ha encontrado jq."
    pause_exit
fi

success "jq encontrado."
}
check_lutris_installation(){
if [[ ! -d "$NORMAL_LUTRIS" ]]; then
    error "No existe la instalación normal de Lutris:"
    echo "  $NORMAL_LUTRIS"
    pause_exit
fi

success "Directorio de Lutris encontrado."

if [[ ! -d "$NORMAL_LUTRIS/runners" ]]; then
    error "No existe el directorio de runners:"
    echo "  $NORMAL_LUTRIS/runners"
    pause_exit
fi

success "Directorio de runners encontrado."

if [[ ! -d "$NORMAL_LUTRIS/runtime" ]]; then
    error "No existe el directorio de runtimes:"
    echo "  $NORMAL_LUTRIS/runtime"
    pause_exit
fi

success "Directorio de runtimes encontrado."
}

check_target_directories(){
mkdir -p "$LIBRARY_BASE" "$BIN_DIR" 2>/dev/null

if [[ ! -w "$LIBRARY_BASE" ]]; then
    error "No se puede escribir en:"
    echo "  $LIBRARY_BASE"
    pause_exit
fi

if [[ ! -w "$BIN_DIR" ]]; then
    error "No se puede escribir en:"
    echo "  $BIN_DIR"
    pause_exit
fi

success "Directorios de destino disponibles."

}
disclaimer(){
# ------------------------------------------------------------
# Cabecera
# ------------------------------------------------------------

clear

echo
echo "========================================"
echo "     CREAR BIBLIOTECA PRIVADA DE LUTRIS"
echo "========================================"
echo

echo "Este script creará una biblioteca de Lutris nueva y vacía."
echo

echo "La biblioteca privada tendrá su propia:"
echo "  - Lista de juegos"
echo "  - Configuración"
echo "  - Base de datos"
echo

echo "Para ahorrar espacio, compartirá con tu Lutris normal:"
echo "  - Wine"
echo "  - Proton / UMU"
echo "  - DXVK / VKD3D"
echo "  - Otros componentes y runtimes"
echo

echo "Los juegos y la configuración de tu Lutris normal"
echo "no se modificarán."
echo

echo "La biblioteca privada se podrá abrir desde su propio lanzador."
echo

read -rp "¿Quieres continuar? [S/n]: " CONTINUE

case "${CONTINUE,,}" in
    n|no)
        echo
        info "Operación cancelada."
        exit 0
        ;;
esac

echo
}
check_environment () {
# ------------------------------------------------------------
# Comprobaciones iniciales
# ------------------------------------------------------------

echo "========================================"
echo "       COMPROBANDO EL ENTORNO"
echo "========================================"
echo
check_dependencies

check_profiles_file

check_lutris_installation

check_target_directories


echo
}

validate_library_name(){
local name="$1"
local name_length

 if [[ -z "$name" ]]; then
       printf '%s\n' "El nombre no puede estar vacío."
        return 1
    fi

    name_length=${#name}

    if (( name_length > MAX_NAME_LENGTH )); then
       printf '%s\n' "El nombre es demasiado largo.
         Longitud máxima: $MAX_NAME_LENGTH caracteres.
         Longitud actual: $name_length caracteres."
        return 1

    fi

    # Permitimos letras ASCII, números, espacios, guion y guion bajo.
    if [[ ! "$name" =~ ^[A-Za-z0-9_][A-Za-z0-9_[:space:]-]*$ ]]; then
       printf '%s\n' "El nombre contiene caracteres no permitidos.
           Solo se permiten:
           Letras, números, espacios, guion (-) y guion bajo (_)."
        return 1
    fi

    if [[ "$name" == "." || "$name" == ".." ]]; then
       printf '%s\n' "Ese nombre no está permitido."
        return 1
    fi

    return 0
}

validate_pin(){
    local pin="$1"

    if [[ ! "$pin" =~ ^[0-9]+$ ]]; then
            printf '%s\n' "El PIN solo puede contener números."
            return 1
    fi

    if (( ${#PIN} < MIN_PIN_LENGTH || ${#PIN} > MAX_PIN_LENGTH )); then
        printf '%s\n' "El PIN debe tener entre $MIN_PIN_LENGTH y $MAX_PIN_LENGTH dígitos."
        return 1
    fi

    return 0
}
generate_slug(){
    local name="$1"
    printf '%s' "$name" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9_-]//g; s/-+/-/g'
}
generate_pin_hash(){
    local pin="$1"
    printf '%s' "$pin" | sha256sum | awk '{print $1}'
}
configure_name (){
# ------------------------------------------------------------
# Nombre
# ------------------------------------------------------------

local validation_error
echo "========================================"
echo "          NOMBRE DE LA BIBLIOTECA"
echo "========================================"
echo

while true; do

    read -rp "Nombre de la biblioteca: " LIBRARY_NAME

    # Eliminar espacios iniciales/finales
    LIBRARY_NAME="${LIBRARY_NAME#"${LIBRARY_NAME%%[![:space:]]*}"}"
    LIBRARY_NAME="${LIBRARY_NAME%"${LIBRARY_NAME##*[![:space:]]}"}"

   if ! validation_error=$(validate_library_name "$LIBRARY_NAME"); then
    error "$validation_error"
    echo
    continue
fi

    # Crear identificador para rutas y ejecutable
    SLUG=$(generate_slug "$LIBRARY_NAME")

    if [[ -z "$SLUG" ]]; then
        error "No se ha podido generar un identificador válido."
        echo
        continue
    fi

    case "$SLUG" in
        lutris|private|normal|default)
            error "Ese nombre está reservado."
            echo
            continue
            ;;
    esac

    PRIVATE_DIR="$LIBRARY_BASE/lutris-$SLUG"
    LAUNCHER="$BIN_DIR/lutris-$SLUG"

    if [[ -e "$PRIVATE_DIR" || -L "$PRIVATE_DIR" ]]; then
        error "Ya existe una biblioteca con ese nombre:"
        echo "  $PRIVATE_DIR"
        echo
        continue
    fi

    if [[ -e "$LAUNCHER" || -L "$LAUNCHER" ]]; then
        error "Ya existe un lanzador con ese nombre:"
        echo "  $LAUNCHER"
        echo
        continue
    fi

    break
done

echo
success "Nombre válido: $LIBRARY_NAME"
success "Identificador: $SLUG"
}

configure_pin () {
read -rp "¿Quieres proteger la biblioteca con un PIN? [S/n]: " USE_PIN

USE_PIN="${USE_PIN,,}"

HAS_PIN=false
PIN_HASH=""

if [[ "$USE_PIN" != "n" && "$USE_PIN" != "no" ]]; then

    while true; do

        echo
        read -rsp "PIN (4-8 dígitos): " PIN
        echo

        if ! validation_error=$(validate_pin "$PIN"); then
            error "$validation_error"
            continue
        fi

        read -rsp "Confirmar PIN: " PIN_CONFIRM
        echo

        if [[ "$PIN" != "$PIN_CONFIRM" ]]; then
            error "Los PIN no coinciden."
            continue
        fi

        PIN_HASH=$(generate_pin_hash "$PIN")

        unset PIN
        unset PIN_CONFIRM

        HAS_PIN=true

        success "PIN configurado correctamente."
        break
    done

else

    success "La biblioteca no tendrá protección mediante PIN."

fi
}


summary(){
echo
echo "========================================"
echo "               RESUMEN"
echo "========================================"
echo

echo "Biblioteca:"
echo "  $LIBRARY_NAME"
echo

echo "Identificador:"
echo "  $SLUG"
echo

echo "Ubicación:"
echo "  $PRIVATE_DIR"
echo

if $HAS_PIN; then
    echo "Protección PIN:"
    echo "  Activada"
else
    echo "Protección PIN:"
    echo "  Desactivada"
fi

echo
echo "Se utilizarán los runners y runtimes"
echo "compartidos con Lutris."
echo

read -rp "¿Crear biblioteca? [S/n]: " FINAL_CONFIRM

case "${FINAL_CONFIRM,,}" in
    n|no)
        echo
        info "Operación cancelada."
        exit 0
        ;;
esac

echo
}

create_library_structure(){
    mkdir -p \
    "$PRIVATE_DIR/lutris/banners" \
    "$PRIVATE_DIR/lutris/coverart" \
    "$PRIVATE_DIR/lutris/games" \
    "$PRIVATE_DIR/lutris/runners" \
    "$PRIVATE_DIR/lutris/runtime"

if [[ ! -d "$PRIVATE_DIR/lutris" ]]; then
    error "No se pudo crear la estructura de Lutris."
    exit 1
fi
success "Estructura de la biblioteca creada."
}

configure_shared_resources(){
# ------------------------------------------------------------
# Compartir Wine
# ------------------------------------------------------------

echo
info "Configurando Wine compartido..."

if [[ -e "$PRIVATE_DIR/lutris/runners/wine" ||
      -L "$PRIVATE_DIR/lutris/runners/wine" ]]; then
    rm -rf -- "$PRIVATE_DIR/lutris/runners/wine"
fi

ln -s -- "$NORMAL_LUTRIS/runners/wine" \
      "$PRIVATE_DIR/lutris/runners/wine"

if [[ "$(readlink "$PRIVATE_DIR/lutris/runners/wine")" == "$NORMAL_LUTRIS/runners/wine" ]]; then
    success "Wine compartido correctamente."
else
    error "No se pudo crear el enlace de Wine."
    rm -rf -- "$PRIVATE_DIR"
    exit 1
fi

# ------------------------------------------------------------
# Compartir runtimes
# ------------------------------------------------------------

echo
info "Configurando runtimes compartidos..."

if [[ -e "$PRIVATE_DIR/lutris/runtime" ||
      -L "$PRIVATE_DIR/lutris/runtime" ]]; then
    rm -rf -- "$PRIVATE_DIR/lutris/runtime"
fi

ln -s -- "$NORMAL_LUTRIS/runtime" \
      "$PRIVATE_DIR/lutris/runtime"

if [[ "$(readlink "$PRIVATE_DIR/lutris/runtime")" == "$NORMAL_LUTRIS/runtime" ]]; then
    success "Runtimes compartidos correctamente."
else
    error "No se pudo crear el enlace de runtimes."
    rm -rf -- "$PRIVATE_DIR"
    exit 1
fi

}

create_private_config(){
# ------------------------------------------------------------
# Crear configuración independiente
# ------------------------------------------------------------

echo
info "Preparando configuración independiente..."

mkdir -p "$PRIVATE_DIR/config"

success "Configuración independiente preparada."
}

save_pin_hash(){
 echo
    info "Configurando protección mediante PIN..."

    printf '%s\n' "$PIN_HASH" > "$PRIVATE_DIR/$HASH_FILE"

    chmod 600 "$PRIVATE_DIR/$HASH_FILE"

    if [[ ! -f "$PRIVATE_DIR/$HASH_FILE" ]]; then
        error "No se pudo guardar el hash del PIN."
        rm -rf -- "$PRIVATE_DIR"
        exit 1
    fi

    success "Hash SHA-256 guardado."
}
create_library(){
# ------------------------------------------------------------
# Creación
# ------------------------------------------------------------

echo "========================================"
echo "          CREANDO BIBLIOTECA"
echo "========================================"
echo

create_library_structure

configure_shared_resources

create_private_config

# ------------------------------------------------------------
# Guardar hash del PIN
# ------------------------------------------------------------

if $HAS_PIN; then
    save_pin_hash
fi
}

create_launcher(){
# ------------------------------------------------------------
# Crear lanzador
# ------------------------------------------------------------

echo
info "Creando lanzador privado..."

cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash

set -u

PRIVATE_DIR="$PRIVATE_DIR"
HASH_FILE="\$PRIVATE_DIR/$HASH_FILE"

launch_lutris() {
    DIR_NAME="\$(basename "\$PRIVATE_DIR")"

    exec env \
        XDG_DATA_HOME="\$PRIVATE_DIR" \
        XDG_CONFIG_HOME="\$HOME/.config/\$DIR_NAME" \
        XDG_CACHE_HOME="\$HOME/.cache/\$DIR_NAME" \
        lutris "\$@"
}

EOF

if $HAS_PIN; then

    cat >> "$LAUNCHER" <<'EOF'
if [[ ! -f "$HASH_FILE" ]]; then
    kdialog --error "No se encuentra la información de acceso." \
        --title "Biblioteca Lutris"
    exit 1
fi

STORED_HASH=$(cat "$HASH_FILE")

PIN=$(kdialog --password "Introduce el PIN para abrir la biblioteca" \
              --title "Biblioteca Lutris")

[[ $? -ne 0 ]] && exit 0

HASH=$(printf '%s' "$PIN" | sha256sum | cut -d' ' -f1)

unset PIN

if [[ "$HASH" != "$STORED_HASH" ]]; then
    kdialog --error "PIN incorrecto." \
            --title "Biblioteca Lutris"
    exit 1
fi

launch_lutris "$@"
EOF

else

    cat >> "$LAUNCHER" <<'EOF'
launch_lutris "$@"
EOF

fi

chmod 700 "$LAUNCHER"

if [[ ! -x "$LAUNCHER" ]]; then
    error "No se pudo crear el lanzador."
    rm -rf -- "$PRIVATE_DIR"
    exit 1
fi

success "Lanzador creado."
}


verify_installation(){
# ------------------------------------------------------------
# Comprobación final
# ------------------------------------------------------------

echo
echo "========================================"
echo "       COMPROBANDO LA INSTALACIÓN"
echo "========================================"
echo

local check_ok=0

if [[ -d "$PRIVATE_DIR/lutris" ]]; then
    success "Biblioteca privada"
else
    error "Falta la biblioteca privada."
    check_ok=1
fi

if [[ -L "$PRIVATE_DIR/lutris/runners/wine" ]]; then
    success "Wine compartido"
else
    error "Falta el enlace de Wine."
    check_ok=1
fi

if [[ -L "$PRIVATE_DIR/lutris/runtime" ]]; then
    success "Runtimes compartidos"
else
    error "Falta el enlace de runtimes."
    check_ok=1
fi

if $HAS_PIN; then
    if [[ -f "$PRIVATE_DIR/$HASH_FILE" ]]; then
        success "Protección mediante PIN"
    else
        error "Falta el hash del PIN."
        check_ok=1
    fi
fi

if [[ -x "$LAUNCHER" ]]; then
    success "Lanzador ejecutable"
else
    error "El lanzador no es ejecutable."
    check_ok=1
fi
return "$check_ok"
}



registry_library_profile(){
# ------------------------------------------------------------
# Registrar biblioteca en lutris-profiles.json
# ------------------------------------------------------------

echo
info "Registrando biblioteca en lutris-profiles.json..."

if [[ ! -f "$PROFILES_JSON" ]]; then
    error "No existe el fichero de perfiles:"
    echo "  $PROFILES_JSON"
    exit 1
fi

PROFILE_PATH="\$HOME/.local/share/lutris-$SLUG"

TMP_PROFILES="${PROFILES_JSON}.tmp"

if jq --arg name "$LIBRARY_NAME" \
      --arg path "$PROFILE_PATH" \
      '.[$name] = $path' \
      "$PROFILES_JSON" > "$TMP_PROFILES"; then

    mv -- "$TMP_PROFILES" "$PROFILES_JSON"
    success "Biblioteca registrada en lutris-profiles.json."

else

    rm -f "$TMP_PROFILES"
    error "No se pudo actualizar lutris-profiles.json."
    exit 1

fi
}

regenerate_kde_menu(){
# ------------------------------------------------------------
# Regenerar menú contextual de KDE
# ------------------------------------------------------------

echo
info "Actualizando menú contextual de Lutris..."

if "$SCRIPT_DIR/update-contextual-menu.sh"; then
    success "Menú contextual actualizado."
else
    warning "No se pudo actualizar automáticamente el menú contextual."
fi
}

resume(){
echo "========================================"
echo "   BIBLIOTECA CREADA CORRECTAMENTE"
echo "========================================"
echo

success "Biblioteca: $LIBRARY_NAME"
echo

echo "Ubicación:"
echo "  $PRIVATE_DIR"
echo

echo "Lanzador:"
echo "  $LAUNCHER"
echo

if $HAS_PIN; then
    success "Protección mediante PIN: activada"
else
    success "Protección mediante PIN: desactivada"
fi
}

final_disclaimer (){
echo
echo "La biblioteca utiliza los runners y runtimes"
echo "compartidos con Lutris."
echo

echo "El script NO ha creado ningún archivo .desktop."
echo
echo "Puedes crear tu propio lanzador .desktop"
echo "utilizando este ejecutable:"
echo
echo "  $LAUNCHER"
echo
echo "Puedes utilizar el icono de Lutris por defecto:"
echo
echo "  Icon=net.lutris.Lutris"
echo

echo "========================================"
echo "                 FIN"
echo "========================================"
echo
}

main(){
    disclaimer
    check_environment
    configure_name
    configure_pin
    summary
    create_library
    create_launcher

if ! verify_installation; then

    error "La creación no ha terminado correctamente."
    echo
    echo "La biblioteca puede estar incompleta:"
    echo "  $PRIVATE_DIR"
    exit 1

fi
registry_library_profile
regenerate_kde_menu
resume
final_disclaimer
}

main



