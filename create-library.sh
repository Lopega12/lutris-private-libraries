#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_JSON="$HOME/.config/lutris-profiles.json"
LIBRARY_BASE="$HOME/.local/share"
NORMAL_LUTRIS="$HOME/.local/share/lutris"
BIN_DIR="$HOME/.local/bin"

HASH_FILE=".access"

MAX_NAME_LENGTH=50
MIN_PIN_LENGTH=4
MAX_PIN_LENGTH=8

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

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

check_profiles_file(){
if [[ ! -f "$PROFILES_JSON" ]]; then

    info "The file lutris-profiles.json does not exist. Creating..."

    mkdir -p "$(dirname "$PROFILES_JSON")"

    cat > "$PROFILES_JSON" <<EOF
{
  "Lutris": "\$HOME/.local/share/lutris"
}
EOF

    if [[ ! -f "$PROFILES_JSON" ]]; then
        error "Could not create lutris-profiles.json."
        pause_exit
    fi

    success "lutris-profiles.json created."

fi

if ! jq empty "$PROFILES_JSON" >/dev/null 2>&1; then
    error "The file lutris-profiles.json could not be created."
    pause_exit
fi

success "lutris-profiles.json is valid."

if ! jq -e 'type == "object"' "$PROFILES_JSON" >/dev/null 2>&1; then
    error "lutris-profiles.json does not contain a valid JSON object."
    pause_exit
fi

success "Valid profile file structure."

}

check_dependencies(){
if ! command -v lutris >/dev/null 2>&1; then
    error "Lutris was not found on the system."
    pause_exit
fi

success "Lutris founded at $(command -v lutris)"


if ! command -v jq >/dev/null 2>&1; then
    error "jq not found"
    pause_exit
fi

success "jq found."
}
check_lutris_installation(){
if [[ ! -d "$NORMAL_LUTRIS" ]]; then
    error "There is no standard installation for Lutris:"
    echo "  $NORMAL_LUTRIS"
    pause_exit
fi

success "Lutris directory found."

if [[ ! -d "$NORMAL_LUTRIS/runners" ]]; then
    error "The runners directory does not exist:"
    echo "  $NORMAL_LUTRIS/runners"
    pause_exit
fi

success "Runners directory found."

if [[ ! -d "$NORMAL_LUTRIS/runtime" ]]; then
    error "The runtimes directory does not exist:"
    echo "  $NORMAL_LUTRIS/runtime"
    pause_exit
fi

success "Runtime directory found."
}

check_target_directories(){
mkdir -p "$LIBRARY_BASE" "$BIN_DIR" 2>/dev/null

if [[ ! -w "$LIBRARY_BASE" ]]; then
    error "I can't write in:"
    echo "  $LIBRARY_BASE"
    pause_exit
fi

if [[ ! -w "$BIN_DIR" ]]; then
    error "I can't write in:"
    echo "  $BIN_DIR"
    pause_exit
fi

success "Available destination directories."

}
disclaimer(){

clear

echo
echo "========================================"
echo "     CREATE PRIVATE LUTRIS LIBRARY"
echo "========================================"
echo

echo "This script will create a new, empty Lutris library."
echo

echo "The private library will have its own:"
echo "  - Game list"
echo "  - Settings"
echo "  - Database"
echo

echo "To save space, it will share the following with your regular Lutris:"
echo "  - Wine"
echo "  - Proton / UMU"
echo "  - DXVK / VKD3D"
echo "  - Other components and runtimes"
echo

echo "The games and settings in your regular Lutris"
echo "will not be modified."
echo

echo "The private library can be opened from its own launcher."
echo

read -rp "Do you want to continue? [Y/n]: " CONTINUE

case "${CONTINUE,,}" in
    n|no)
        echo
        info "Operation canceled."
        exit 0
        ;;
esac

echo
}
check_environment () {

echo "========================================"
echo "       CHECKING THE ENVIRONMENT"
echo "========================================"
echo
check_dependencies

check_profiles_file

check_lutris_installation

check_target_directories

}

validate_library_name(){
local name="$1"
local name_length

 if [[ -z "$name" ]]; then
       printf '%s\n' "The name field cannot be left blank."
        return 1
    fi

    name_length=${#name}

    if (( name_length > MAX_NAME_LENGTH )); then
       printf '%s\n' "The name is too long.
         Maximum length: $MAX_NAME_LENGTH characters.
         Current length: $name_length characters."
        return 1

    fi

    # We allow ASCII letters, numbers, spaces, hyphens, and underscores.
    if [[ ! "$name" =~ ^[A-Za-z0-9_][A-Za-z0-9_[:space:]-]*$ ]]; then
       printf '%s\n' "The name contains invalid characters.
           Only the following are allowed:
           Letters, numbers, spaces, hyphens (-), and underscores (_)."
        return 1
    fi

    if [[ "$name" == "." || "$name" == ".." ]]; then
       printf '%s\n' "That name is not allowed."
        return 1
    fi

    return 0
}

validate_pin(){
    local pin="$1"

    if [[ ! "$pin" =~ ^[0-9]+$ ]]; then
            printf '%s\n' "The PIN can only contain numbers."
            return 1
    fi

    if (( ${#pin} < MIN_PIN_LENGTH || ${#pin} > MAX_PIN_LENGTH )); then
        printf '%s\n' "The PIN must be between $MIN_PIN_LENGTH and $MAX_PIN_LENGTH digits long."
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
local validation_error
echo "========================================"
echo "          LIBRARY NAME"
echo "========================================"
echo

while true; do

    read -rp "Library Name: " LIBRARY_NAME

    # Drop unnecesary spaces
    LIBRARY_NAME="${LIBRARY_NAME#"${LIBRARY_NAME%%[![:space:]]*}"}"
    LIBRARY_NAME="${LIBRARY_NAME%"${LIBRARY_NAME##*[![:space:]]}"}"

   if ! validation_error=$(validate_library_name "$LIBRARY_NAME"); then
    error "$validation_error"
    echo
    continue
fi

    # Create an identifier for routes and the executable
    SLUG=$(generate_slug "$LIBRARY_NAME")

    if [[ -z "$SLUG" ]]; then
        error "A valid identifier could not be generated."
        echo
        continue
    fi

    case "$SLUG" in
        lutris|private|normal|default)
            error "That name is reserved."
            echo
            continue
            ;;
    esac

    PRIVATE_DIR="$LIBRARY_BASE/lutris-$SLUG"
    LAUNCHER="$BIN_DIR/lutris-$SLUG"

    if [[ -e "$PRIVATE_DIR" || -L "$PRIVATE_DIR" ]]; then
        error "There is already a library with that name:"
        echo "  $PRIVATE_DIR"
        echo
        continue
    fi

    if [[ -e "$LAUNCHER" || -L "$LAUNCHER" ]]; then
        error "There is already a pitcher with that name:"
        echo "  $LAUNCHER"
        echo
        continue
    fi

    break
done

echo
success "Valid name: $LIBRARY_NAME"
success "Identifier: $SLUG"
}

configure_pin () {
read -rp "Do you want to protect the library with a PIN? [Y/n]: " USE_PIN

USE_PIN="${USE_PIN,,}"

HAS_PIN=false
PIN_HASH=""

if [[ "$USE_PIN" != "n" && "$USE_PIN" != "no" ]]; then

    while true; do

        echo
        read -rsp "PIN (4-8 digits): " PIN
        echo

        if ! validation_error=$(validate_pin "$PIN"); then
            error "$validation_error"
            continue
        fi

        read -rsp "Confirm PIN: " PIN_CONFIRM
        echo

        if [[ "$PIN" != "$PIN_CONFIRM" ]]; then
            error "The PINs do not match."
            continue
        fi

        PIN_HASH=$(generate_pin_hash "$PIN")

        unset PIN
        unset PIN_CONFIRM

        HAS_PIN=true

        success "PIN configured correctly."
        break
    done

else

    success "The library will not be protected by a PIN."

fi
}


summary(){
echo
echo "========================================"
echo "               RESUME"
echo "========================================"
echo

echo "Library:"
echo "  $LIBRARY_NAME"
echo

echo "Identifier:"
echo "  $SLUG"
echo

echo "Location:"
echo "  $PRIVATE_DIR"
echo

if $HAS_PIN; then
    echo "PIN protection:"
    echo "  Enabled"
else
    echo "PIN protection:"
    echo "  Disabled"
fi

echo
echo "The runners and runtimes shared with Lutris will be used."
echo

read -rp "Create library? [Y/n]: " FINAL_CONFIRM

case "${FINAL_CONFIRM,,}" in
    n|no)
        echo
        info "Operation canceled."
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
    error "The Lutris structure could not be created."
    exit 1
fi
success "Structure of the library created."
}

link_lutris_resource(){
    local source="$1"
    local target="$2"
    local resource_name="$3"

    info "Configuring the shared  $resource_name ..."

    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf -- "$target"
    fi

    ln -s -- "$source" "$target"

    if [[ "$(readlink "$target")" == "$source" ]]; then
        success "$resource_name  was shared successfully"
    else
        error "The link for $resource_name could not be created."
        rm -rf -- "$PRIVATE_DIR"
        exit 1
    fi


}

configure_shared_resources(){
# ------------------------------------------------------------
# Wine
# ------------------------------------------------------------
link_lutris_resource \
    "$NORMAL_LUTRIS/runners/wine" \
    "$PRIVATE_DIR/lutris/runners/wine" \
    "Wine"

# ------------------------------------------------------------
# runtimes
# ------------------------------------------------------------
link_lutris_resource \
    "$NORMAL_LUTRIS/runtime" \
    "$PRIVATE_DIR/lutris/runtime" \
    "Runtimes"


}

create_private_config(){
echo
info "Preparing standalone configuration..."

mkdir -p "$PRIVATE_DIR/config"

success "Independent configuration ready."
}

save_pin_hash(){
 echo
    info "Setting up PIN protection..."

    printf '%s\n' "$PIN_HASH" > "$PRIVATE_DIR/$HASH_FILE"

    chmod 600 "$PRIVATE_DIR/$HASH_FILE"

    if [[ ! -f "$PRIVATE_DIR/$HASH_FILE" ]]; then
        error "The PIN hash could not be saved."
        rm -rf -- "$PRIVATE_DIR"
        exit 1
    fi

    success "Hash saved.."
}
create_library(){
echo "========================================"
echo "          CREATING A LIBRARY"
echo "========================================"
echo

create_library_structure

configure_shared_resources

create_private_config

if $HAS_PIN; then
    save_pin_hash
fi
}

create_launcher(){
echo
info "Creating a private launcher..."

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
    kdialog --error "Access information not found." \
        --title "Lutris Library"
    exit 1
fi

STORED_HASH=$(cat "$HASH_FILE")

PIN=$(kdialog --password "Enter the PIN to open the library" \
              --title "Lutris Library")

[[ $? -ne 0 ]] && exit 0

HASH=$(printf '%s' "$PIN" | sha256sum | cut -d' ' -f1)

unset PIN

if [[ "$HASH" != "$STORED_HASH" ]]; then
    kdialog --error "Incorrect PIN." \
            --title "Lutris Library"
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
    error "The launcher could not be created."
    rm -rf -- "$PRIVATE_DIR"
    exit 1
fi

success "Launcher created."
}


verify_installation(){
echo
echo "========================================"
echo "       CHECKING THE INSTALLATION"
echo "========================================"
echo

local check_ok=0

if [[ -d "$PRIVATE_DIR/lutris" ]]; then
    success "Private Library"
else
    error "The private library is missing."
    check_ok=1
fi

if [[ -L "$PRIVATE_DIR/lutris/runners/wine" ]]; then
    success "Wine linked"
else
    error "The Wine link is missing."
    check_ok=1
fi

if [[ -L "$PRIVATE_DIR/lutris/runtime" ]]; then
    success "Runtimes linked"
else
    error "The runtimes link is missing."
    check_ok=1
fi

if $HAS_PIN; then
    if [[ -f "$PRIVATE_DIR/$HASH_FILE" ]]; then
        success "PIN Protection success. "
    else
        error "The PIN hash is missing."
        check_ok=1
    fi
fi

if [[ -x "$LAUNCHER" ]]; then
    success "Executable launcher"
else
    error "The launcher is not executable."
    check_ok=1
fi
return "$check_ok"
}



registry_library_profile(){

echo
info "Registering library in lutris-profiles.json..."

if [[ ! -f "$PROFILES_JSON" ]]; then
    error "The profile file does not exist:"
    echo "  $PROFILES_JSON"
    return 1
fi

PROFILE_PATH="$HOME/.local/share/lutris-$SLUG"

TMP_PROFILES="${PROFILES_JSON}.tmp"

if jq --arg name "$LIBRARY_NAME" \
      --arg path "$PROFILE_PATH" \
      '.[$name] = $path' \
      "$PROFILES_JSON" > "$TMP_PROFILES"; then

    if ! mv -f -- "$TMP_PROFILES" "$PROFILES_JSON"; then
        error "The lutris-profiles.json file could not be updated."
        return 1
    fi

else

    rm -f "$TMP_PROFILES"
    error "The lutris-profiles.json file could not be updated."
    return 1

fi

success "Library registered in lutris-profiles.json."
return 0
}

regenerate_kde_menu(){

echo
info "Updating the Lutris context menu..."

if "$SCRIPT_DIR/update-contextual-menu.sh"; then
    success "Updated context menu."
else
    warning "The context menu could not be updated automatically."
fi
}

resume(){
echo "========================================"
echo "   LIBRARY CREATED SUCCESSFULLY "
echo "========================================"
echo

success "Library: $LIBRARY_NAME"
echo

echo "Location: "
echo "  $PRIVATE_DIR"
echo

echo "Launcher:"
echo "  $LAUNCHER"
echo

if $HAS_PIN; then
    success "PIN protection: enabled"
else
    success "PIN protection: disabled"
fi
}

final_disclaimer (){
echo
echo "The library uses the runners and runtimes"
echo "shared with Lutris."
echo

echo "The script has NOT created any .desktop files."
echo
echo "You can create your own .desktop launcher"
echo "using this executable:"
echo
echo "  $LAUNCHER"
echo
echo "You can use the default Lutris icon:"
echo
echo "  Icon=net.lutris.Lutris"
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

    error "The creation process did not complete successfully."
    echo
    echo "The library may be incomplete:"
    echo "  $PRIVATE_DIR"
    exit 1

fi

if ! registry_library_profile; then
    error "The library could not be registered."
    echo "Reverting creation..."

    rm -rf -- "$PRIVATE_DIR"
    rm -f -- "$LAUNCHER"

    exit 1
fi

read -rp "Do you want to update the KDE context menu? [Y/n]: " UPDATE_MENU

case "${UPDATE_MENU,,}" in
    n|no)
        info "The context menu has not been updated."
        ;;
    *)
        regenerate_kde_menu
        ;;
esac
resume
final_disclaimer
}

main



