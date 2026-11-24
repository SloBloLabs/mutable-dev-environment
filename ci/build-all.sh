#!/usr/bin/env bash
# Build every module application (HEX, plus the audio-update WAV where the
# module makefile has a `wav` target) and every bootloader in a firmware
# checkout. Used by the release workflow; also runnable inside the Vagrant VM:
#
#   /vagrant/ci/build-all.sh /vagrant/parasites
set -euo pipefail

source_dir="${1:?usage: $0 <firmware-checkout>}"
script_dir=$(cd "$(dirname "$0")" && pwd)
cd "$source_dir"
# python-compat makes the WAV encoders work with the numpy 1.16 installed here.
export PYTHONPATH="$script_dir/python-compat:.:${PYTHONPATH:-}"

# Fold log sections on GitHub Actions; plain headers elsewhere (e.g. in the VM).
group() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::group::$*"; else echo "=== $*"; fi; }
endgroup() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::endgroup::"; fi; }

# The stm_audio_bootloader commit pinned by pichenettes/eurorack predates
# STM32H7 support, but beads/makefile asks its encoder for `-t stm32h7`. This
# commit only adds that target (stm32f4 output is unchanged), so it is used
# for the WAV step of such modules, then the pinned encoder is restored.
H7_ENCODER_COMMIT=e870782a4136661557e8aeb7d88079ab61f808b5
ENCODER_DIR=stm_audio_bootloader
ENCODER=qpsk/encoder.py

make_wav() {
  local makefile=$1
  if grep -q -- '-t stm32h7' "$makefile" && ! grep -q stm32h7 "$ENCODER_DIR/$ENCODER"; then
    echo "Using $ENCODER_DIR@${H7_ENCODER_COMMIT:0:7} encoder (STM32H7 support) for $makefile"
    git -C "$ENCODER_DIR" cat-file -e "$H7_ENCODER_COMMIT^{commit}" 2>/dev/null ||
      git -C "$ENCODER_DIR" fetch -q origin "$H7_ENCODER_COMMIT"
    git -C "$ENCODER_DIR" show "$H7_ENCODER_COMMIT:$ENCODER" > "$ENCODER_DIR/$ENCODER"
    local status=0
    make -f "$makefile" wav || status=$?
    git -C "$ENCODER_DIR" checkout -- "$ENCODER"
    return $status
  fi
  make -f "$makefile" wav
}

# The generated resources.cc/.h files are committed. In a fresh clone every
# file gets an arbitrary timestamp, so make may think resources.cc is older
# than resources/*.py and try to regenerate it (which can fail, e.g. on
# case-sensitive file systems because of PPGVOCAL.SYX in plaits). Mark the
# committed files as up to date.
for generated in */resources.cc */resources.h; do
  [ -f "$generated" ] && touch "$generated"
done

for makefile in */makefile */makefile.mk; do
  [ -f "$makefile" ] || continue
  case "$makefile" in avrlib/*|avrlibx/*) continue ;; esac
  module=${makefile%/makefile*}
  group "$source_dir: $module"
  mkdir -p "build/$module"
  make -f "$makefile"
  if grep -q '^wav:' "$makefile"; then
    make_wav "$makefile"
  fi
  endgroup
done

for makefile in */bootloader/makefile */bootloader/makefile.mk; do
  [ -f "$makefile" ] || continue
  module=${makefile%/bootloader/makefile*}
  group "$source_dir: ${module}_bootloader"
  mkdir -p "build/${module}_bootloader"
  make -f "$makefile"
  endgroup
done
