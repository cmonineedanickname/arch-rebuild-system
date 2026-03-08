#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BASE="$REPO_ROOT/packages"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

RAW_ALL="$TMPDIR/all-packages.raw"
ALL_SORTED="$TMPDIR/all-packages.sorted"
INSTALLED_SORTED="$TMPDIR/installed.sorted"

cat \
  "$BASE/core.txt" \
  "$BASE/desktop.txt" \
  "$BASE/apps.txt" \
  "$BASE/dev.txt" \
  "$BASE/laptop.txt" \
  "$BASE/machine.txt" \
  "$BASE/aur.txt" \
  > "$RAW_ALL"

sort -u "$RAW_ALL" > "$ALL_SORTED"
pacman -Qqe | sort -u > "$INSTALLED_SORTED"

echo "== Packages defined in layers but not currently installed =="
comm -23 "$ALL_SORTED" "$INSTALLED_SORTED" || true
echo

echo "== Explicitly installed packages not covered by any layer =="
comm -13 "$ALL_SORTED" "$INSTALLED_SORTED" || true
echo

echo "== Duplicate package entries across layer files =="
sort "$RAW_ALL" | uniq -d || true
echo
