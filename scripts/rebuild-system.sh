#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BASE="$REPO_ROOT/packages"

DRY_RUN=false
WANT_CORE=false
WANT_DESKTOP=false
WANT_APPS=false
WANT_DEV=false
WANT_LAPTOP=false
WANT_MACHINE=false
WANT_AUR=false

usage() {
  cat <<'EOF'
Usage:
  rebuild-system.sh [options]

Options:
  --core        Install core layer
  --desktop     Install desktop layer
  --apps        Install apps layer
  --dev         Install dev layer
  --laptop      Install laptop layer
  --machine     Install machine-specific layer
  --aur         Install AUR layer
  --all         Install all repo layers + AUR
  --dry-run     Print what would be installed without doing it
  -h, --help    Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --core) WANT_CORE=true ;;
    --desktop) WANT_DESKTOP=true ;;
    --apps) WANT_APPS=true ;;
    --dev) WANT_DEV=true ;;
    --laptop) WANT_LAPTOP=true ;;
    --machine) WANT_MACHINE=true ;;
    --aur) WANT_AUR=true ;;
    --all)
      WANT_CORE=true
      WANT_DESKTOP=true
      WANT_APPS=true
      WANT_DEV=true
      WANT_LAPTOP=true
      WANT_MACHINE=true
      WANT_AUR=true
      ;;
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

if ! $WANT_CORE && ! $WANT_DESKTOP && ! $WANT_APPS && ! $WANT_DEV && ! $WANT_LAPTOP && ! $WANT_MACHINE && ! $WANT_AUR; then
  echo "No layers selected." >&2
  usage
  exit 1
fi

install_repo_layer() {
  local file="$1"
  local label="$2"

  if [[ ! -f "$file" ]]; then
    echo "Missing layer file: $file" >&2
    exit 1
  fi

  echo
  echo "==> $label"
  if $DRY_RUN; then
    cat "$file"
  else
    sudo pacman -S --needed --asexplicit - < "$file"
  fi
}

bootstrap_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi

  echo
  echo "==> Bootstrapping yay"

  if $DRY_RUN; then
    echo "Would install git if needed"
    echo "Would clone yay from AUR into a temp directory"
    echo "Would run: makepkg -srci --noconfirm"
    return 0
  fi

  if ! pacman -Q git >/dev/null 2>&1; then
    sudo pacman -S --needed --asexplicit git
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

  if [[ ! -f "$file" ]]; then
    echo "Missing layer file: $file" >&2
    exit 1
  fi

  echo
  echo "==> AUR packages"

  if $DRY_RUN; then
    cat "$file"
  else
    bootstrap_yay
    yay -S --needed --asexplicit --answerclean None --answerdiff None - < "$file"
  fi
}

echo "Selected layers (fixed install order):"
$WANT_CORE && echo " - core"
$WANT_DESKTOP && echo " - desktop"
$WANT_APPS && echo " - apps"
$WANT_DEV && echo " - dev"
$WANT_LAPTOP && echo " - laptop"
$WANT_MACHINE && echo " - machine"
$WANT_AUR && echo " - aur"

$WANT_CORE && install_repo_layer "$BASE/core.txt" "Core"
$WANT_DESKTOP && install_repo_layer "$BASE/desktop.txt" "Desktop"
$WANT_APPS && install_repo_layer "$BASE/apps.txt" "Apps"
$WANT_DEV && install_repo_layer "$BASE/dev.txt" "Dev"
$WANT_LAPTOP && install_repo_layer "$BASE/laptop.txt" "Laptop"
$WANT_MACHINE && install_repo_layer "$BASE/machine.txt" "Machine-specific"
$WANT_AUR && install_aur_layer "$BASE/aur.txt"

echo
echo "Done."
