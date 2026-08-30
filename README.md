# Lutris Private Libraries

Create and manage independent Lutris game libraries from a single Linux user account.

Each library has its own games database and configuration while sharing Wine runners and Lutris runtimes with the main Lutris installation.

The project is designed for users who want to keep different groups of games separated without duplicating large Wine runners, DXVK, VKD3D or Lutris runtime files.

## Features

- Create independent Lutris libraries.
- Each library has its own game database.
- Independent Lutris configuration.
- Independent cache.
- Optional PIN protection.
- Share Wine runners between libraries.
- Share Lutris runtimes between libraries.
- Add games to a specific library from the KDE/Dolphin context menu.
- Automatically register and remove libraries from the profile configuration.
- Automatically regenerate the KDE service menu.
- Remove a complete library and its associated launcher.
- No system-wide installation required.
- User paths are detected dynamically, making the project portable between installations.

## How it works

The main Lutris installation normally uses:

    ~/.local/share/lutris

A private library is created as:

    ~/.local/share/lutris-<library>

For example:

    ~/.local/share/lutris-retro
    ~/.local/share/lutris-private
    ~/.local/share/lutris-work
    ~/.local/share/lutris-testing

Each library has its own:

- Games
- Lutris database
- Configuration
- Cache

Wine runners and Lutris runtimes are shared with the main Lutris installation to avoid unnecessary duplication.

## Library profiles

Libraries are registered in:

    ~/.config/lutris-profiles.json

Example:

```json
{
  "Lutris": "$HOME/.local/share/lutris",
  "Private": "$HOME/.local/share/lutris-private",
  "Retro": "$HOME/.local/share/lutris-retro"
}
```
The file is automatically created if it does not exist.

PIN protection

A library can optionally be protected with a PIN.

The PIN itself is never stored.

Only its SHA-256 hash is stored inside the library:

~/.local/share/lutris-<library>/.access

The launcher asks for the PIN before starting the corresponding Lutris instance.

The PIN protection is intended as a convenience/privacy feature, not as a strong security boundary.

Context menu integration

The project can generate a KDE service menu that allows a Windows executable to be imported into a selected Lutris library.

The generated menu is located at:

~/.local/share/kio/servicemenus/addtolutris.desktop

The menu is generated dynamically from:

~/.config/lutris-profiles.json
KDE / Dolphin note

The context-menu integration depends on KDE Plasma/KIO service-menu behaviour.

There is currently a KDE/KIO issue that may prevent the generated submenu from appearing correctly in Dolphin even though the .desktop file is generated correctly.

The project therefore does not rely on the context menu for its core functionality.

Games can still be imported through the generated library launcher or by running the import script directly.

Requirements
Linux
Lutris
Bash
jq
Python 3
KDE Plasma / KIO for the optional Dolphin context-menu integration
Project structure
lutris-private-libraries/
├── README.md
├── ARCHITECTURE.md
├── INSTALLATION.md
├── LICENSE
│
├── create-library.sh
├── remove-library.sh
├── update-menu.sh
└── import-game.sh
Basic workflow

Create a library:

./create-library.sh

Remove a library:

./remove-library.sh

Update the KDE context menu manually:

./update-menu.sh

Import a game:

./import-game.sh "/path/to/game.exe" "LibraryName"
Design goals

The project intentionally avoids duplicating Lutris runners and runtimes.

The goal is to provide isolation where it matters:

Game library
Database
Configuration
Cache

while sharing large common components:

Wine
Proton / UMU
DXVK
VKD3D
Lutris runtimes

This keeps disk usage low while allowing multiple independent Lutris environments.
