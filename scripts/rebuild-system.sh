#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BASE="$REPO_ROOT/packages"

DRY_RUN=false
UPDATE_SYSTEM=false

WANT_CORE=false
WANT_GUI=false
WANT_DESKTOP_MACHINE=false
WANT_APPS=false
WANT_DEV=false
WANT_LAPTOP=false
WANT_PRINT_SCAN=false
WANT_VIRT=false
WANT_AUR=false

usage() {
  cat <<'EOF'
Usage:
  rebuild-system.sh [options]

Options:
  --core              Install core layer
  --gui               Install GUI layer
  --desktop-machine   Install desktop-machine layer
  --apps              Install apps layer
  --dev               Install dev layer
  --laptop            Install laptop layer
  --print-scan        Install print/scan layer
  --virt              Install virtualization layer
  --aur               Install AUR layer
  --update            Run pacman -Syu before installing layers
  --dry-run           Print what would be installed without doing it
  -h, --help          Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --core) WANT_CORE=true ;;
    --gui) WANT_GUI=true ;;
    --desktop-machine) WANT_DESKTOP_MACHINE=true ;;
    --apps) WANT_APPS=true ;;
    --dev) WANT_DEV=true ;;
    --laptop) WANT_LAPTOP=true ;;
    --print-scan) WANT_PRINT_SCAN=true ;;
    --virt) WANT_VIRT=true ;;
    --aur) WANT_AUR=true ;;
    --update) UPDATE_SYSTEM=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

if $WANT_LAPTOP && $WANT_DESKTOP_MACHINE; then
  echo "Do not select both --laptop and --desktop-machine." >&2
  exit 1
fi

if ! $WANT_CORE && ! $WANT_GUI && ! $WANT_DESKTOP_MACHINE && ! $WANT_APPS && \
   ! $WANT_DEV && ! $WANT_LAPTOP && ! $WANT_PRINT_SCAN && ! $WANT_VIRT && ! $WANT_AUR; then
  echo "No layers selected." >&2
  usage
  exit 1
fi

install_repo_layer() {
  local file="$1"
  local label="$2"

  [[ -f "$file" ]] || return 0
  [[ -s "$file" ]] || return 0

  echo
  echo "==> $label"

  if $DRY_RUN; then
    cat "$file"
  else
    sudo pacman -S --needed - < "$file"
  fi
}

bootstrap_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  echo
  echo "==> Bootstrapping yay"

  if $DRY_RUN; then
    echo "Would install git"
    echo "Would clone yay and build it"
    return 0
  fi

  if ! pacman -Q git >/dev/null 2>&1; then
    sudo pacman -S --needed git
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd "$tmpdir/yay"
    makepkg -srci --noconfirm
  )
}

install_aur_layer() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  [[ -s "$file" ]] || return 0

  echo
  echo "==> AUR packages"

  if $DRY_RUN; then
    cat "$file"
  else
    bootstrap_yay
    yay -S --needed --answerclean None --answerdiff None - < "$file"
  fi
}

mark_layer_explicit() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  [[ -s "$file" ]] || return 0

  if $DRY_RUN; then
    echo "Would mark packages from $file as explicit"
  else
    xargs -r sudo pacman -D --asexplicit < "$file"
  fi
}

enable_services() {
  local file="$1"
  local label="$2"

  [[ -f "$file" ]] || return 0
  [[ -s "$file" ]] || return 0

  echo
  echo "==> Enabling $label services"

  while read -r service; do
    [[ -z "$service" ]] && continue

    if $DRY_RUN; then
      echo "Would enable $service.service"
    else
      sudo systemctl enable "$service.service"
    fi
  done < "$file"
}

if $UPDATE_SYSTEM; then
  echo
  echo "==> Updating system"
  if $DRY_RUN; then
    echo "sudo pacman -Syu"
  else
    sudo pacman -Syu
  fi
fi

echo "Selected layers (install order):"
$WANT_CORE && echo " - core"
$WANT_GUI && echo " - gui"
$WANT_DESKTOP_MACHINE && echo " - desktop-machine"
$WANT_LAPTOP && echo " - laptop"
$WANT_APPS && echo " - apps"
$WANT_DEV && echo " - dev"
$WANT_PRINT_SCAN && echo " - print-scan"
$WANT_VIRT && echo " - virt"
$WANT_AUR && echo " - aur"

# Install in safe order
$WANT_CORE && install_repo_layer "$BASE/core.txt" "Core"
$WANT_GUI && install_repo_layer "$BASE/gui.txt" "GUI"
$WANT_DESKTOP_MACHINE && install_repo_layer "$BASE/desktop-machine.txt" "Desktop machine"
$WANT_LAPTOP && install_repo_layer "$BASE/laptop.txt" "Laptop"
$WANT_APPS && install_repo_layer "$BASE/apps.txt" "Apps"
$WANT_DEV && install_repo_layer "$BASE/dev.txt" "Dev"
$WANT_PRINT_SCAN && install_repo_layer "$BASE/print-scan.txt" "Print/scan"
$WANT_VIRT && install_repo_layer "$BASE/virt.txt" "Virtualization"
$WANT_AUR && install_aur_layer "$BASE/aur.txt"

# Mark explicit AFTER installs
$WANT_CORE && mark_layer_explicit "$BASE/core.txt"
$WANT_GUI && mark_layer_explicit "$BASE/gui.txt"
$WANT_DESKTOP_MACHINE && mark_layer_explicit "$BASE/desktop-machine.txt"
$WANT_LAPTOP && mark_layer_explicit "$BASE/laptop.txt"
$WANT_APPS && mark_layer_explicit "$BASE/apps.txt"
$WANT_DEV && mark_layer_explicit "$BASE/dev.txt"
$WANT_PRINT_SCAN && mark_layer_explicit "$BASE/print-scan.txt"
$WANT_VIRT && mark_layer_explicit "$BASE/virt.txt"
$WANT_AUR && mark_layer_explicit "$BASE/aur.txt"

# Enable matching service layers only
$WANT_CORE && enable_services "$REPO_ROOT/services/core.txt" "core"
$WANT_GUI && enable_services "$REPO_ROOT/services/gui.txt" "gui"
$WANT_LAPTOP && enable_services "$REPO_ROOT/services/laptop.txt" "laptop"
$WANT_PRINT_SCAN && enable_services "$REPO_ROOT/services/print-scan.txt" "print-scan"
$WANT_VIRT && enable_services "$REPO_ROOT/services/virt.txt" "virt"

echo
echo "Done."
