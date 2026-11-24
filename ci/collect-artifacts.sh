#!/usr/bin/env bash
# Package the build outputs of one firmware checkout into <out_dir>/<label>.zip.
# Layout inside the zip: <label>/<build-dir>/<file>, where <build-dir> is e.g.
# `clouds` or `clouds_bootloader`.
set -euo pipefail

source_dir="${1:?usage: $0 <firmware-checkout> <label> <out_dir>}"
label="${2:?missing label}"
out_dir="${3:?missing out_dir}"

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/$label" "$out_dir"
out_dir=$(cd "$out_dir" && pwd)

count=0
for dir in "$source_dir"/build/*/; do
  name=$(basename "$dir")
  for file in "$dir"*.hex "$dir"*.elf "$dir"*.bin "$dir"*.map "$dir"*.wav; do
    [ -f "$file" ] || continue
    mkdir -p "$staging/$label/$name"
    cp "$file" "$staging/$label/$name/"
    count=$((count + 1))
  done
done

[ "$count" -gt 0 ] || { echo "No artifacts found in $source_dir/build" >&2; exit 1; }

rm -f "$out_dir/$label.zip"
(cd "$staging" && zip -qr "$out_dir/$label.zip" "$label")
echo "$label.zip: $count files"
