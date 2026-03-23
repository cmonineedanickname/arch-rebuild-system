#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BASE="$REPO_ROOT/packages"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

INSTALLED_SORTED="$TMPDIR/installed.sorted"
RAW_ALL="$TMPDIR/all-packages.raw"
ALL_SORTED="$TMPDIR/all-packages.sorted"

pacman -Qqe | sort -u > "$INSTALLED_SORTED"

: > "$RAW_ALL"

while IFS= read -r -d '' layer_file; do
  layer_name="$(basename "$layer_file")"
  layer_tmp="$TMPDIR/${layer_name}.sorted"
  missing_tmp="$TMPDIR/${layer_name}.missing"

  sed 's/#.*$//' "$layer_file" \
    | sed '/^[[:space:]]*$/d' \
    | sort -u > "$layer_tmp"

  cat "$layer_tmp" >> "$RAW_ALL"

  comm -23 "$layer_tmp" "$INSTALLED_SORTED" > "$missing_tmp" || true

  if [[ -s "$missing_tmp" ]]; then
    echo "== Packages defined in layer ${layer_name} but not currently installed =="
    cat "$missing_tmp"
    echo
  fi
done < <(find "$BASE" -maxdepth 1 -type f -name '*.txt' -print0 | sort -z)

sort -u "$RAW_ALL" > "$ALL_SORTED"

UNCOVERED_TMP="$TMPDIR/uncovered.sorted"
comm -13 "$ALL_SORTED" "$INSTALLED_SORTED" > "$UNCOVERED_TMP" || true

echo "== Explicitly installed packages not covered by any layer =="
cat "$UNCOVERED_TMP"
echo

echo "== Duplicate package entries across layer files =="
find "$BASE" -maxdepth 1 -type f -name '*.txt' -print0 \
  | sort -z \
  | xargs -0 sed 's/#.*$//' \
  | sed '/^[[:space:]]*$/d' \
  | sort \
  | uniq -d || true
echo
