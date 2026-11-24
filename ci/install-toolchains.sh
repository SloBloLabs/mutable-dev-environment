#!/usr/bin/env bash
# Install the same toolchains as 0_install-toolchain.sh on an x86-64
# Ubuntu 22.04 GitHub Actions runner (no VM). Tarballs are downloaded to
# ${DOWNLOAD_DIR} so the workflow can cache them.
set -euo pipefail

DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/toolchain-downloads}"
mkdir -p "$DOWNLOAD_DIR"

export DEBIAN_FRONTEND=noninteractive
sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential binutils-avr gcc-avr avr-libc zip \
  libc6:i386 libncurses5:i386 libstdc++6:i386 \
  python2.7 python2.7-dev

fetch() { # <url> <md5>
  local archive="$DOWNLOAD_DIR/$(basename "$1")"
  if [ ! -f "$archive" ]; then
    wget -nv -O "$archive" "$1"
  fi
  echo "$2  $archive" | md5sum -c - >&2
  echo "$archive"
}

# Original Mutable Instruments toolchain (GCC 4.8.3), also the default /usr/local/arm.
archive=$(fetch https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2 4869e6a6e1dc11ea0835e8b8213bb194)
sudo tar xjf "$archive" -C /usr/local
sudo rm -rf /usr/local/arm-4.8.3
sudo mv /usr/local/gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3
sudo ln -sfn /usr/local/arm-4.8.3 /usr/local/arm

# Beads (GCC 4.9).
archive=$(fetch https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q3-update/+download/gcc-arm-none-eabi-4_9-2015q3-20150921-linux.tar.bz2 8a4a74872830f80c788c944877d3ad8c)
sudo tar xjf "$archive" -C /usr/local
sudo rm -rf /usr/local/arm-4.9
sudo mv /usr/local/gcc-arm-none-eabi-4_9-2015q3 /usr/local/arm-4.9

# Parasites (GCC 5.4.1).
archive=$(fetch https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q3-update/+download/gcc-arm-none-eabi-5_4-2016q3-20160926-linux.tar.bz2 f7004b904541c09a8a0a7a52883c9e5b)
sudo tar xjf "$archive" -C /usr/local
# The tarball already extracts to the directory name the Parasites makefiles expect.

# The AVR makefiles look for avr-gcc under CrossPack-AVR; the makefiles call `python` (2.7).
sudo ln -sfn /usr /usr/local/CrossPack-AVR
sudo ln -sfn /usr/bin/python2.7 /usr/local/bin/python

wget -nv -O "$DOWNLOAD_DIR/get-pip.py" https://bootstrap.pypa.io/pip/2.7/get-pip.py
sudo python2.7 "$DOWNLOAD_DIR/get-pip.py" "pip<21"
sudo python2.7 -m pip install "numpy==1.16.6"

/usr/local/arm-4.8.3/bin/arm-none-eabi-gcc --version | head -1
/usr/local/arm-4.9/bin/arm-none-eabi-gcc --version | head -1
/usr/local/gcc-arm-none-eabi-5_4-2016q3/bin/arm-none-eabi-gcc --version | head -1
avr-gcc --version | head -1
python --version
