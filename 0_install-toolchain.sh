#!/usr/bin/env bash

# set -x

if [ "$(dpkg --print-architecture)" = "arm64" ]; then
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    sed -i 's#^deb http://ports.ubuntu.com/ubuntu-ports/#deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/#' /etc/apt/sources.list
    dpkg --add-architecture i386
    cat > /etc/apt/sources.list.d/i386.list <<'EOF'
deb [arch=i386] https://archive.ubuntu.com/ubuntu jammy main universe
deb [arch=i386] https://archive.ubuntu.com/ubuntu jammy-updates main universe
deb [arch=i386] https://security.ubuntu.com/ubuntu jammy-security main universe
EOF
    printf '%s\n' 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99no-translations

    apt-get update -o Acquire::http::Timeout=30 -o Acquire::Retries=2
    apt-get install -y \
        autoconf automake autotools-dev build-essential binutils-avr \
        cowsay figlet gcc-avr git language-pack-en libftdi-dev libftdi1 \
        libncurses5:i386 libstdc++6:i386 libtool libc6:i386 \
        libusb-1.0-0 libusb-1.0-0-dev locales openocd pkg-config \
        python2.7 python2.7-dev python3 python3-matplotlib python3-numpy \
        python3-scipy python3-serial binfmt-support qemu-user-static \
        stlink-tools wget avr-libc avrdude

    locale-gen en_US.UTF-8
    mkdir -p /usr/local/bin /usr/local
    ln -sfn /usr/bin/python2.7 /usr/local/bin/python
    ln -sfn /usr /usr/local/CrossPack-AVR

    cd /home/vagrant
    if [ ! -x /usr/local/arm-4.8.3/bin/arm-none-eabi-gcc ]; then
        toolchain_archive=gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2
        wget -nv "https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/$toolchain_archive"
        echo "4869e6a6e1dc11ea0835e8b8213bb194  $toolchain_archive" | md5sum -c -
        tar xjf "$toolchain_archive"
        rm -f /usr/local/arm /usr/local/arm-4.8.3
        mv gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3
        rm "$toolchain_archive"
    fi
    ln -sfn /usr/local/arm-4.8.3 /usr/local/arm

    if [ ! -x /usr/local/arm-4.9/bin/arm-none-eabi-gcc ]; then
        beads_toolchain_archive=gcc-arm-none-eabi-4_9-2015q3-20150921-linux.tar.bz2
        wget -nv "https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q3-update/+download/$beads_toolchain_archive"
        echo "8a4a74872830f80c788c944877d3ad8c  $beads_toolchain_archive" | md5sum -c -
        tar xjf "$beads_toolchain_archive"
        rm -rf /usr/local/arm-4.9
        mv gcc-arm-none-eabi-4_9-2015q3 /usr/local/arm-4.9
        rm "$beads_toolchain_archive"
    fi

    if [ ! -x /usr/local/gcc-arm-none-eabi-5_4-2016q3/bin/arm-none-eabi-gcc ]; then
        parasites_toolchain_archive=gcc-arm-none-eabi-5_4-2016q3-20160926-linux.tar.bz2
        wget -nv "https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q3-update/+download/$parasites_toolchain_archive"
        echo "f7004b904541c09a8a0a7a52883c9e5b  $parasites_toolchain_archive" | md5sum -c -
        tar xjf "$parasites_toolchain_archive"
        mv gcc-arm-none-eabi-5_4-2016q3 /usr/local/gcc-arm-none-eabi-5_4-2016q3
        rm "$parasites_toolchain_archive"
    fi

    mkdir -p /opt/local/share
    ln -sfn /usr/share/openocd /opt/local/share/openocd

    cd /home/vagrant
    wget -nv https://bootstrap.pypa.io/pip/2.7/get-pip.py
    python2.7 get-pip.py "pip<21"
    python2.7 -m pip install --no-binary=numpy "numpy==1.16.6"
    rm get-pip.py

    printf '%s\n' \
        'export LC_ALL=en_US.UTF-8' \
        'export LANGUAGE=en_US' \
        'export PYTHONPATH=.:$PYTHONPATH' \
        >> /home/vagrant/.bashrc

    cat > /etc/udev/rules.d/60-programmers.rules <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="0003", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002a", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002b", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2104", GROUP="users", MODE="0666"
SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="users", MODE="0666", SYMLINK+="ftdi-usbserial"
EOF
    udevadm control --reload-rules
    udevadm trigger
    exit 0
fi

# fix apt warnings like:
# ==> default: dpkg-preconfigure: unable to re-open stdin: No such file or directory
# http://serverfault.com/questions/500764/dpkg-reconfigure-unable-to-re-open-stdin-no-file-or-directory
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

# fix apt warnings like:
# ==> default: dpkg-preconfigure: unable to re-open stdin: No such file or directory
# http://serverfault.com/questions/500764/dpkg-reconfigure-unable-to-re-open-stdin-no-file-or-directory
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

# Install some additional drivers, including support for FTDI dongles
# http://askubuntu.com/questions/541443/how-to-install-usbserial-and-ftdi-sio-modules-to-14-04-trusty-vagrant-box
sudo apt-get update -qq
sudo apt-get install -y linux-image-extra-virtual
sudo modprobe ftdi_sio vendor=0x0403 product=0x6001

# Install basic development tools
sudo dpkg --add-architecture i386
sudo apt-get update -qq
sudo apt-get install -y build-essential autotools-dev autoconf pkg-config libusb-1.0-0 libusb-1.0-0-dev libftdi1 libftdi-dev git libc6:i386 libncurses5:i386 libstdc++6:i386 cowsay figlet language-pack-en
sudo locale-gen UTF-8

# Install python
sudo apt-get install -y python2.7 python-numpy python-scipy python-matplotlib python3 python3-serial

# Install development tools for avr
sudo apt-get install -y gcc-avr binutils-avr avr-libc avrdude

# The makefile from Mutable Instruments expects the avr-gcc binaries to be
# in a different directory.
sudo ln -s /usr /usr/local/CrossPack-AVR

# Install openocd
cd /home/vagrant
wget -nv https://downloads.sourceforge.net/project/openocd/openocd/0.11.0/openocd-0.11.0.tar.gz --no-check-certificate
tar xfz openocd-0.11.0.tar.gz
cd openocd-0.11.0
./configure --enable-ftdi --enable-stlink
make
sudo make install
cd /home/vagrant
rm -rf openocd-0.11.0
rm *.tar.gz

# Install stlink
cd /home/vagrant
wget -nv https://github.com/texane/stlink/archive/v1.1.0.tar.gz --no-check-certificate
tar xfz v1.1.0.tar.gz
cd stlink-1.1.0
./autogen.sh
./configure
make
sudo make install
sudo cp 49-stlink*.rules /etc/udev/rules.d/
cd /home/vagrant
rm -rf stlink-1.1.0
rm *.tar.gz

# Allow non-root users to access USB devices such as Atmel AVR and Olimex
# programmers, FTDI dongles...
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="0003", GROUP="users", MODE="0666"' >> /etc/udev/rules.d/60-programmers.rules
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002a", GROUP="users", MODE="0666"' >> /etc/udev/rules.d/60-programmers.rules
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="15ba", ATTRS{idProduct}=="002b", GROUP="users", MODE="0666"' >> /etc/udev/rules.d/60-programmers.rules
echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2104", GROUP="users", MODE="0666"' >> /etc/udev/rules.d/60-programmers.rules
echo 'SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="users", MODE="0666", SYMLINK+="ftdi-usbserial"' >> /etc/udev/rules.d/60-programmers.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Install toolchain for STM32F
cd /home/vagrant
wget -nv https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2 --no-check-certificate
tar xjf gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2
sudo mv gcc-arm-none-eabi-4_8-2013q4 /usr/local/arm-4.8.3/
rm *.tar.bz2
# (We're progressively checking that all STM32F1 projects can also be built with
# this gcc version instead of 4.5.2).
ln -s /usr/local/arm-4.8.3 /usr/local/arm

# Add "." to PYTHONPATH, and set default language
echo 'export LC_ALL=en_US.UTF-8' >> /home/vagrant/.bashrc
echo 'export LANGUAGE=en_US' >> /home/vagrant/.bashrc
echo 'export PYTHONPATH=.:$PYTHONPATH' >> /home/vagrant/.bashrc
