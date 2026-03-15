#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/たぬき式ゆっくり"
DOWNLOADS_DIR="$ROOT_DIR/downloads"
DEFAULT_VERSION="$(date +%Y%m%d)"
VERSION="${1:-$DEFAULT_VERSION}"
ARCHIVE_BASENAME="たぬき式ゆっくり_ver${VERSION}"
VERSIONED_ZIP="$DOWNLOADS_DIR/${ARCHIVE_BASENAME}.zip"
LATEST_ZIP="$DOWNLOADS_DIR/tanuki-yukkuri.zip"

find_source_dir() {
  local candidate
  for candidate in "$@"; do
    if [[ -d "$ROOT_DIR/$candidate" ]]; then
      printf '%s\n' "$ROOT_DIR/$candidate"
      return 0
    fi
  done
  return 1
}

copy_item() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$target_path"
  rsync -a --delete \
    --exclude='.DS_Store' \
    --exclude='._*' \
    --exclude='__MACOSX' \
    "$source_path"/ "$target_path"/
}

cleanup_metadata() {
  local target_dir="$1"

  find "$target_dir" -name '.DS_Store' -exec rm -f {} +
  find "$target_dir" -name '._*' -exec rm -f {} +
  find "$target_dir" -name '__MACOSX' -type d -prune -exec rm -rf {} +
}

build_zip() {
  local source_dir="$1"
  local output_zip="$2"

  SOURCE_DIR="$source_dir" OUTPUT_ZIP="$output_zip" python3 - <<'PY'
from pathlib import Path
import os
import unicodedata
import zipfile

source_dir = Path(os.environ["SOURCE_DIR"])
output_zip = Path(os.environ["OUTPUT_ZIP"])

def is_junk(path: Path) -> bool:
    return (
        path.name == ".DS_Store"
        or path.name.startswith("._")
        or "__MACOSX" in path.parts
    )

with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for path in sorted(source_dir.rglob("*")):
        if is_junk(path):
            continue

        relative = path.relative_to(source_dir.parent)
        arcname = unicodedata.normalize("NFC", relative.as_posix())

        if path.is_dir():
            zf.writestr(f"{arcname}/", b"")
        else:
            zf.write(path, arcname)
PY
}

REIMU_SOURCE="$(find_source_dir "たぬき霊夢")"
MARISA_SOURCE="$(find_source_dir "たぬき魔理沙")"
SAMPLE_SOURCE="$(find_source_dir "たぬきサンプル" "たぬきサンプル")"

mkdir -p "$BUILD_DIR" "$DOWNLOADS_DIR"
find "$BUILD_DIR" -mindepth 1 -exec rm -rf {} +

copy_item "$REIMU_SOURCE" "$BUILD_DIR/たぬき霊夢"
copy_item "$MARISA_SOURCE" "$BUILD_DIR/たぬき魔理沙"
copy_item "$SAMPLE_SOURCE" "$BUILD_DIR/たぬきサンプル"
cp "$ROOT_DIR/TERMS.txt" "$BUILD_DIR/TERMS.txt"
cp "$ROOT_DIR/README.txt" "$BUILD_DIR/README.txt"

cleanup_metadata "$BUILD_DIR"
rm -f "$VERSIONED_ZIP" "$LATEST_ZIP"

build_zip "$BUILD_DIR" "$VERSIONED_ZIP"

cp "$VERSIONED_ZIP" "$LATEST_ZIP"

printf 'Built: %s\n' "$VERSIONED_ZIP"
printf 'Updated: %s\n' "$LATEST_ZIP"
