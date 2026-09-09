# Usage

`lutris-private-libraries` provides several scripts for creating and managing private Lutris libraries.

All scripts can be run directly after completing the installation steps described in [INSTALLATION.md](INSTALLATION.md).

---

## Create a private library

Use `create-library.sh` to create a new private Lutris library:

```bash
./create-library.sh
```

The script guides you through the complete creation process, including:

1. Selecting or creating a profile.
2. Choosing the library name.
3. Optionally configuring a PIN.
4. Creating the private library structure.
5. Creating the required Lutris configuration.
6. Creating the library launcher.
7. Registering the library in the profile registry.
8. Optionally updating the KDE context menu.

Private libraries are created independently from the main Lutris library while sharing Wine runners and Lutris runtime components.

---

## Remove a private library

Use `remove-library.sh` to remove an existing private library:

```bash
./remove-library.sh
```

The script handles the complete removal process, including:

* Private library files.
* Library configuration.
* Lutris launcher.
* Symbolic links.
* Cached data associated with the library.
* Profile registry entry.

Using the removal script is recommended instead of manually deleting a private library directory.

---

## Import a game

Use `import-game.sh` to import a game into one of the configured private libraries:

```bash
./import-game.sh
```

The script will:

1. Select the target profile.
2. Detect the game executable or installer.
3. Prepare the required installer information.
4. Import the game into the selected private library.

Game imports are performed against the selected private library rather than the main Lutris installation.

---

## Update the KDE context menu

Use `update-contextual-menu.sh` to regenerate the KDE Dolphin context menu integration:

```bash
./update-contextual-menu.sh
```

The generated service menu allows games to be added to the configured private Lutris libraries from Dolphin.

The service menu is stored at:

```text
~/.local/share/kio/servicemenus/addtolutris.desktop
```

The menu can be regenerated at any time after creating or removing private libraries.

---

## Profiles

Profiles are used to associate private libraries with their configuration.

The profile registry is stored at:

```text
~/.config/lutris-profiles.json
```

Profiles are selected by the scripts when an operation requires a target library or configuration.

Profile names are handled independently from the physical library directory names.

---

## PIN protection

A private library can optionally be configured with a PIN during creation.

The PIN is used as an additional protection mechanism for operations involving the private library.

PIN configuration is optional and can be skipped when creating a library.

---

## Typical workflow

A typical setup and usage flow is:

```text
Create profile
    ↓
Create private library
    ↓
Import games
    ↓
Use the private library
    ↓
Regenerate KDE menu when needed
    ↓
Remove the library when no longer required
```

For example:

```bash
./create-library.sh
./import-game.sh
./update-contextual-menu.sh
```

When the library is no longer needed:

```bash
./remove-library.sh
```

---

## Main and private Lutris libraries

The project keeps private libraries separate from the main Lutris installation.

For example:

```text
Main Lutris:
~/.local/share/lutris/

Private library:
~/.local/share/lutris-retro/
```

Private libraries maintain their own configuration and game data while sharing Wine runners and Lutris runtime components with the main installation.

This allows multiple isolated Lutris libraries without duplicating the large runtime components required by Lutris.
