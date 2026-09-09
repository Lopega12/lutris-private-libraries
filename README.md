# Lutris Private Libraries

Create and manage independent Lutris game libraries from a single Linux user account.

Each library has its own games database and configuration while sharing Wine runners and Lutris runtimes with the main Lutris installation.

The project is designed for users who want to keep different groups of games separated without duplicating large Wine runners, DXVK, VKD3D or Lutris runtime files.

## Features

* Create independent Lutris libraries.
* Each library has its own game database.
* Independent Lutris configuration.
* Independent cache.
* Optional PIN protection.
* Share Wine runners between libraries.
* Share Lutris runtimes between libraries.
* Add games to a specific library from the KDE/Dolphin context menu.
* Automatically register and remove libraries from the profile configuration.
* Optionally regenerate the KDE service menu.
* Remove a complete library and its associated launcher.
* No system-wide installation required.
* User paths are detected dynamically, making the project portable between installations.

## How it works

The main Lutris installation normally uses:

```text
~/.local/share/lutris/
```

A private library is created as:

```text
~/.local/share/lutris-<library>/
```

For example:

```text
~/.local/share/lutris-retro/
~/.local/share/lutris-private/
~/.local/share/lutris-work/
~/.local/share/lutris-testing/
```

Each library has its own:

* Games
* Lutris database
* Configuration
* Cache

Wine runners and Lutris runtimes are shared with the main Lutris installation to avoid unnecessary duplication.

## Library profiles

Libraries are registered in:

```text
~/.config/lutris-profiles.json
```

For example:

```json
{
  "Lutris": "$HOME/.local/share/lutris",
  "Private": "$HOME/.local/share/lutris-private",
  "Retro": "$HOME/.local/share/lutris-retro"
}
```

The file is automatically created if it does not exist.

## PIN protection

A library can optionally be protected with a PIN.

The PIN itself is never stored.

Only its SHA-256 hash is stored inside the library:

```text
~/.local/share/lutris-<library>/.access
```

The launcher asks for the PIN before starting the corresponding Lutris instance.

PIN protection is intended as a convenience and privacy feature, not as a strong security boundary.

## Context menu integration

The project can generate a KDE service menu that allows a Windows executable to be imported into a selected Lutris library.

The generated menu is located at:

```text
~/.local/share/kio/servicemenus/addtolutris.desktop
```

The menu is generated dynamically from:

```text
~/.config/lutris-profiles.json
```

### KDE / Dolphin note

The context-menu integration depends on KDE Plasma and KIO service-menu behaviour.

There is currently a KDE/KIO issue that may prevent the generated submenu from appearing correctly in Dolphin even though the `.desktop` file is generated correctly.

The project therefore does not rely on the context menu for its core functionality.

Games can still be imported by running the import script directly or through the available library workflow.

## Requirements

* Linux
* Bash
* Lutris
* jq

KDE Plasma and KIO are only required for the optional Dolphin context-menu integration.

## Installation

See the [Installation Guide](docs/INSTALLATION.md) for complete installation instructions.

## Usage

See the [Usage Guide](docs/USAGE.md) for information about creating, removing and managing private libraries.

## Project structure

```text
lutris-private-libraries/
├── README.md
├── LICENSE
├── docs/
│   ├── INSTALLATION.md
│   └── USAGE.md
│
├── create-library.sh
├── remove-library.sh
├── import-game.sh
└── update-contextual-menu.sh
```

## Basic workflow

Create a library:

```bash
./create-library.sh
```

Import a game:

```bash
./import-game.sh
```

Update the KDE context menu:

```bash
./update-contextual-menu.sh
```

Remove a library:

```bash
./remove-library.sh
```

See the [Usage Guide](docs/USAGE.md) for detailed instructions and examples.

## Design goals

The project intentionally avoids duplicating Lutris runners and runtimes.

The goal is to provide isolation where it matters:

* Game library
* Database
* Configuration
* Cache

while sharing large common components:

* Wine
* Proton / UMU
* DXVK
* VKD3D
* Lutris runtimes

This keeps disk usage low while allowing multiple independent Lutris environments.

## License

This project is licensed under the terms of the included [LICENSE](LICENSE) file.
