# Arch Rebuild System

## Overview

This repository contains a **reproducible rebuild system for an Arch Linux workstation/laptop setup**.

The goal of the project is simple:

> If the machine dies or the system needs to be rebuilt, the entire environment can be restored quickly from a clean Arch install.

The rebuild system manages:

* package installation
* explicit vs dependency tracking
* AUR packages
* system services
* configuration tracking
* logical package layers

The system has been **tested with full rebuilds inside a VM** to ensure it reliably reproduces the working environment.

---

# Repository Structure

```
arch-rebuild-system/
│
├─ config/
│  ├─ greetd/
│  │   └─ config.toml
│  └─ pacman.conf
│
├─ packages/
│  ├─ core.txt
│  ├─ desktop.txt
│  ├─ apps.txt
│  ├─ dev.txt
│  ├─ laptop.txt
│  ├─ machine.txt
│  └─ aur.txt
│
├─ services/
│  ├─ core.txt
│  ├─ desktop.txt
│  ├─ laptop.txt
│  └─ machine.txt
│
├─ scripts/
│  ├─ rebuild-system.sh
│  └─ check-package-layers.sh
│
└─ README.md
```

---

# Layer System

The rebuild system organizes packages into **logical layers**.

This makes the system easier to understand and allows rebuilding only specific parts if necessary.

| Layer   | Purpose                                             |
| ------- | --------------------------------------------------- |
| core    | base system tools and essential utilities           |
| desktop | graphical environment (Hyprland, portals, UI tools) |
| apps    | user applications                                   |
| dev     | development tools                                   |
| laptop  | laptop-specific tools (power management etc.)       |
| machine | hardware or workstation specific tools              |
| aur     | packages installed from the AUR                     |

Example rebuild:

```
./scripts/rebuild-system.sh --update --core --desktop
```

Full rebuild:

```
./scripts/rebuild-system.sh --update --all
```

---

# Package Installation Logic

Packages are installed using:

```
pacman -S --needed
```

After installation the rebuild script ensures that **only the packages defined in the layer files remain explicit**.

```
pacman -D --asexplicit
```

This ensures:

* dependencies stay dependencies
* layer packages remain explicit
* the system stays clean

---

# AUR Handling

AUR packages are defined in:

```
packages/aur.txt
```

The rebuild script installs AUR packages using **yay**.

If yay is not installed, the script automatically bootstraps it:

1. installs git
2. clones the yay repository
3. builds yay using `makepkg`
4. installs all AUR packages

---

# Service Management

Services are managed through the **services layer system**.

Each layer can define services that should be enabled.

Example files:

```
services/core.txt
services/desktop.txt
services/laptop.txt
services/machine.txt
```

Each file contains a list of systemd services that should be enabled.

Example:

```
NetworkManager
greetd
power-profiles-daemon
```

During rebuild, the script enables these services automatically:

```
systemctl enable <service>.service
```

This ensures the rebuilt system starts the correct services without manual configuration.

---

# Drift Detection

To prevent configuration drift, the repository includes:

```
scripts/check-package-layers.sh
```

This script compares:

* installed explicit packages
* packages defined in layer files

It detects:

* packages defined but not installed
* explicit packages not defined in layers
* duplicate packages across layers

This keeps the rebuild definition clean and consistent.

---

# Example Rebuild Workflow

Rebuilding a system typically looks like this:

```
install Arch
install git
clone repository
run rebuild script
copy configs
reboot
```

Example:

```
git clone <repo>
cd arch-rebuild-system
./scripts/rebuild-system.sh --update --all
```

A full rebuild usually takes **10–15 minutes**.

---

# Design Philosophy

The rebuild system is designed with several goals:

### reproducibility

A system should be rebuildable from scratch with minimal manual work.

### transparency

All installed packages are tracked in plain text files.

### modularity

Logical layers allow rebuilding only parts of the system.

### maintainability

Configuration drift can be detected and corrected easily.

---

# TODO

Planned improvements.

## Dotfile automation

Currently configuration files are copied manually.

Future goal:

```
config/
→ automatically deployed to system
```

Possible targets:

```
/etc
~/.config
```

---

## Service verification

Add tooling similar to package drift detection:

* compare enabled services
* verify services match layer definitions

---

## Improve rebuild script UX

Possible improvements:

* clearer logging
* progress output
* early sudo authentication

---

# Summary

This project provides a **clean, layered, reproducible Arch Linux setup**.

Key features:

* layered package management
* explicit dependency tracking
* automatic AUR installation
* automatic service enabling
* drift detection tooling
* rebuild validation in VM

The system allows restoring a full workstation environment quickly and reliably from a fresh Arch install.

