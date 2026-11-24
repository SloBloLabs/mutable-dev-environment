#!/usr/bin/env bash
# Package the build outputs of one firmware checkout into <out_dir>/<label>.zip,
# together with NOTICE.txt and the license texts that apply to the binaries.
# Layout inside the zip: <label>/<build-dir>/<file> (e.g. `clouds` or
# `clouds_bootloader`), <label>/NOTICE.txt and <label>/LICENSES/.
set -euo pipefail

usage="usage: $0 <firmware-checkout> <label> <out_dir> <title> <source-repo-url>"
source_dir="${1:?$usage}"
label="${2:?$usage}"
out_dir="${3:?$usage}"
title="${4:?$usage}"
repo_url="${5:?$usage}"

script_dir=$(cd "$(dirname "$0")" && pwd)
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
root="$staging/$label"
mkdir -p "$root/LICENSES" "$out_dir"
out_dir=$(cd "$out_dir" && pwd)

# Modules (and their bootloaders) built on avrlib/avrlibx, which are GPLv3.
gpl_modules=()
for makefile in "$source_dir"/*/makefile "$source_dir"/*/bootloader/makefile; do
  [ -f "$makefile" ] || continue
  grep -q avrlib "$makefile" || continue
  module=${makefile#"$source_dir"/}
  gpl_modules+=("${module%%/*}")
done
gpl_modules=($(printf '%s\n' "${gpl_modules[@]}" | sort -u))

count=0
mit_modules=()
for dir in "$source_dir"/build/*/; do
  name=$(basename "$dir")
  module=${name%_bootloader}
  found=0
  for file in "$dir"*.hex "$dir"*.elf "$dir"*.bin "$dir"*.map "$dir"*.wav; do
    [ -f "$file" ] || continue
    mkdir -p "$root/$name"
    cp "$file" "$root/$name/"
    count=$((count + 1))
    found=1
  done
  if [ "$found" = 1 ] && [[ " ${gpl_modules[*]:-} " != *" $module "* ]]; then
    mit_modules+=("$module")
  fi
done
[ "$count" -gt 0 ] || { echo "No artifacts found in $source_dir/build" >&2; exit 1; }
mit_modules=($(printf '%s\n' "${mit_modules[@]}" | sort -u))

# --- License texts -----------------------------------------------------------
require_file() { [ -f "$1" ] || { echo "Missing license file: $1" >&2; exit 1; }; }

for name in stmlib stm_audio_bootloader avr_audio_bootloader; do
  require_file "$source_dir/$name/LICENSE"
  cp "$source_dir/$name/LICENSE" "$root/LICENSES/$name-LICENSE.txt"
done
# ARM CMSIS-DSP and any other license files shipped inside stmlib/third_party.
while IFS= read -r file; do
  rel=${file#"$source_dir"/stmlib/third_party/}
  cp "$file" "$root/LICENSES/third_party-$(echo "$rel" | tr '/' '_')"
done < <(find "$source_dir/stmlib/third_party" -type f \( -iname 'license*' -o -iname 'copying*' \) 2>/dev/null)
cp "$script_dir/licenses/BSD-3-Clause.txt" "$root/LICENSES/BSD-3-Clause.txt"

copy_system_license() { # <system file name> <name in zip>
  local src="/usr/share/common-licenses/$1"
  if [ -f "$src" ]; then
    cp "$src" "$root/LICENSES/$2"
  elif [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "Missing $src" >&2
    exit 1
  else
    echo "Warning: $src not found; $2 omitted from this local test package" >&2
  fi
}
copy_system_license GPL-3 GPL-3.0.txt
copy_system_license Apache-2.0 Apache-2.0.txt

# --- NOTICE ------------------------------------------------------------------
source_commit=$(git -C "$source_dir" rev-parse HEAD)
builder_url="https://github.com/${GITHUB_REPOSITORY:-SloBloLabs/mutable-dev-environment}"
builder_commit="${GITHUB_SHA:-$(git -C "$script_dir" rev-parse HEAD 2>/dev/null || echo unknown)}"
modules_list() { [ "$#" -gt 0 ] && printf '%s' "$*" | sed 's/ /, /g' || echo "(none)"; }

{
  cat <<EOF
$title - unofficial firmware builds
================================================================================

These files were compiled automatically from public source code:

  Source:  $repo_url
  Commit:  $source_commit
           $repo_url/tree/$source_commit
  Builder: $builder_url (commit $builder_commit)
           This repository holds the build scripts and toolchain versions.

Each <module>/ folder holds the application and each <module>_bootloader/
folder the bootloader, as .hex/.elf/.bin/.map and, where the module supports
audio updates, .wav files.

NOT OFFICIAL, NO WARRANTY
-------------------------
These are unofficial community builds. They are not made, endorsed or
supported by Mutable Instruments or Emilie Gillet. "Mutable Instruments" is a
registered trademark of its owner. Firmware that is not produced by the
original manufacturer is flashed at your own risk. The software is provided
"as is", without warranty of any kind. Some firmware (for example Beads) has
not been verified on a module. You are responsible for checking a build before
installing it.

Licenses
--------
The source code is by Emilie Gillet (and, for Parasites, further contributors)
under these licenses; see LICENSES/ for the texts:

  * GNU General Public License v3 or later (LICENSES/GPL-3.0.txt) for the AVR
    projects, which link avrlib/avrlibx:
      $(modules_list "${gpl_modules[@]:-}")
  * MIT License (LICENSES/stmlib-LICENSE.txt and the LICENSE files of the
    audio bootloaders) for the STM32 projects:
      $(modules_list "${mit_modules[@]:-}")
  * Third-party code compiled into the STM32 firmware, by their own licenses:
      - STMicroelectronics peripheral drivers: MCD-ST Liberty SW License
        Agreement V2 (http://www.st.com/software_license_agreement_liberty_v2)
        for the STM32F0/F1/F3/F4 drivers, and BSD 3-Clause
        (LICENSES/BSD-3-Clause.txt) for the STM32G4/H7 HAL drivers. The
        copyright holder is named in each source file header.
      - ARM CMSIS and CMSIS-DSP: BSD-style license (see LICENSES/third_party-*)
        and Apache-2.0 (LICENSES/Apache-2.0.txt) for newer CMSIS headers.
      - The GNU Arm Embedded toolchain runtime libraries (libgcc, newlib) that
        the linker adds to every ELF/HEX file.

Source code for the GPL-licensed firmware
-----------------------------------------
The complete corresponding source code of every file in this package is
available, free of charge, at the repository and commit named above, including
these Git submodules at exactly these commits:

EOF
  git -C "$source_dir" submodule foreach --quiet --recursive \
    'printf "  %s  %s  %s\n" "$sha1" "$displaypath" "$(git config --get remote.origin.url)"'
  cat <<EOF

The build scripts and toolchain versions used are in the builder repository
above. If any of these links stop working, ask the builder repository's owners
for a copy of the source.
EOF
} > "$root/NOTICE.txt"

rm -f "$out_dir/$label.zip"
(cd "$staging" && zip -qr "$out_dir/$label.zip" "$label")
echo "$label.zip: $count build files, $(ls "$root/LICENSES" | wc -l | tr -d ' ') license files"
