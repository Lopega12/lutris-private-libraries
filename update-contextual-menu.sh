#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMPORT_GAME="$SCRIPT_DIR/import-game.sh"
CONF_FILE="$HOME/.config/lutris-profiles.json"
TARGET_DIR="$HOME/.local/share/kio/servicemenus/"
DESKTOP_FILE="$TARGET_DIR/addtolutris.desktop"

mkdir -p "$TARGET_DIR"

profiles=$(jq -r 'keys[]' "$CONF_FILE" 2>/dev/null)
[ -z "$profiles" ] && exit 1

actions_list=""
for prof in $profiles; do
    actions_list="${actions_list}AddLutris_${prof};"
done

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Service
MimeType=application/x-ms-dos-executable;
Actions=${actions_list}
X-KDE-Priority=TopLevel

EOF

for prof in $profiles; do
    cat <<EOF >> "$DESKTOP_FILE"
[Desktop Action AddLutris_${prof}]
Name=Biblioteca $prof
Icon=net.lutris.Lutris
Exec=$IMPORT_GAME "%f" "$prof"

EOF
done
chmod +x $DESKTOP_FILE
# Regenerar base de datos de servicios de KDE Plasma 6
kbuildsycoca6 --noincremental 2>/dev/null
