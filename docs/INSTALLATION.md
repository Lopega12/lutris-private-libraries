# Installation

## Requirements

* Linux
* Bash
* Lutris
* jq

### Optional KDE integration

The KDE Dolphin context-menu integration additionally requires:

* KDE Plasma
* KIO service-menu support
* `kbuildsycoca6`

No root privileges or system-wide installation are required.

---

## Getting the project

Clone the repository:

```bash
git clone https://github.com/Lopega12/lutris-private-libraries.git
cd lutris-private-libraries
```

The project does not require a traditional installation step. The scripts can be run directly from the cloned repository.

After cloning the repository, make the scripts executable:

```bash
chmod +x create-library.sh remove-library.sh import-game.sh update-contextual-menu.sh
```

The scripts can then be run directly:

```bash
./create-library.sh
./remove-library.sh
./import-game.sh
./update-contextual-menu.sh
```

No root privileges are required.

---

## First setup

Before creating a private library, make sure Lutris is installed and working normally.

Start the library creation process with:

```bash
./create-library.sh
```

The script will guide you through:

1. Selecting a profile.
2. Choosing the library name.
3. Optionally configuring a PIN.
4. Creating the private library structure.
5. Creating the required configuration and launcher.
6. Registering the library in the profile registry.
7. Optionally regenerating the KDE context menu.

The profile registry is stored at:

```text
~/.config/lutris-profiles.json
```

---

## KDE context-menu integration

KDE Dolphin integration is optional.

When creating a library, `create-library.sh` asks whether the KDE context menu should be updated.

If enabled, the service menu is generated at:

```text
~/.local/share/kio/servicemenus/addtolutris.desktop
```

The menu can also be regenerated manually:

```bash
./update-contextual-menu.sh
```

This is useful if the list of private libraries changes after the initial setup.

---

## Library layout

Private libraries are stored separately from the main Lutris installation.

For example:

```text
~/.local/share/lutris-retro/
```

The main Lutris installation remains in its normal location:

```text
~/.local/share/lutris/
```

Private libraries use the shared Lutris Wine runners and runtime components rather than maintaining separate copies of them.

Each private library maintains its own configuration and game data.

---

## Troubleshooting

### A required command is missing

The scripts check their required dependencies before performing operations.

If a dependency is missing, install it using your Linux distribution's package manager and run the script again.

The main external dependencies are:

```text
lutris
jq
```

For KDE integration, also make sure:

```text
kbuildsycoca6
```

is available.

### The KDE context menu does not appear

Regenerate the menu manually:

```bash
./update-contextual-menu.sh
```

Then restart Dolphin or allow KDE's service-menu cache to refresh.

### A private library cannot be removed

Use the removal script rather than deleting the directory manually:

```bash
./remove-library.sh
```

This allows the project to clean up the associated configuration, launcher, registry entry, cache and symbolic links.

---

## Uninstalling

The repository itself can be removed normally:

```bash
rm -rf lutris-private-libraries
```

This does **not** remove any private Lutris libraries that were previously created.

Remove those libraries first using:

```bash
./remove-library.sh
```

If KDE integration is no longer needed, the generated service-menu file can also be removed:

```text
~/.local/share/kio/servicemenus/addtolutris.desktop
```

The profile registry is stored at:

```text
~/.config/lutris-profiles.json
```

If it is no longer needed, it can be removed after all private libraries have been removed.
