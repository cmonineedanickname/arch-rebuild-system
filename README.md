# Arch Rebuild System

Small rebuild system for my Arch Linux setup.

The goal is to keep the system **lean and reproducible** by tracking:

* package layers
* important system configuration
* rebuild scripts

Everything lives in `~/.local/rebuild-system`.

---

# Structure

```
rebuild-system/
├── config/
│   ├── pacman.conf
│   └── greetd/
│       └── config.toml
│
├── notes/
│
├── packages/
│   ├── core.txt
│   ├── desktop.txt
│   ├── apps.txt
│   ├── dev.txt
│   ├── laptop.txt
│   ├── machine.txt
│   └── aur.txt
│
└── scripts/
    ├── rebuild-system.sh
    └── check-package-layers.sh
```

---

# Package Layers

Packages are grouped into layers inside `packages/`.

Install order:

1. core
2. desktop
3. apps
4. dev
5. laptop
6. machine
7. aur

Each file contains a plain list of package names.

---

# Rebuild

Install layers with:

```
./scripts/rebuild-system.sh --all
```

Or install specific layers:

```
./scripts/rebuild-system.sh --core --desktop
```

Dry run:

```
./scripts/rebuild-system.sh --all --dry-run
```

The script installs repo packages via `pacman` and AUR packages via `yay`.
If `yay` is missing it will be bootstrapped automatically.

---

# System Config

Important files from `/etc` are stored in `config/`.

Currently tracked:

* pacman.conf
* greetd/config.toml

---

# Package Audit

Check if the system matches the layer definitions:

```
./scripts/check-package-layers.sh
```

This shows:

* packages defined but not installed
* installed packages not covered by a layer
* duplicates across layers

