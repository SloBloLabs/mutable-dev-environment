# Vagrant environment for Mutable Instruments modules hacking

This configuration file and this shellscript create a Linux (ubuntu) virtual machine configured with all the right tools for compiling and installing the firmware of Mutable Instruments' modules.

## Kudos and inspiration

* Adafruit's [ARM Toolchain for Vagrant](https://github.com/adafruit/ARM-toolchain-vagrant)
* Novation's [LaunchPad pro](https://github.com/dvhdr/launchpad-pro)

## Requirements

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads)
* [Vagrant](https://www.vagrantup.com/downloads.html)

On Apple Silicon Macs, use VirtualBox 7.1 or later. Vagrant selects an ARM64
Ubuntu 22.04 guest there; Intel hosts continue to use the original Ubuntu
Trusty environment. The ARM64 guest runs the pinned GCC 4.8-2013-q4 Linux
toolchain through QEMU user-mode emulation because that toolchain is an x86
binary. This preserves the pinned compiler version, but builds may be slower
than on Intel.

The Extension pack consists of a file with the `vbox-extpack` extension.  On windows, double click on it.  On OS X or Linux, the file needs to be installed from the command line with the command:

    VBoxManage extpack install <filename>

Finally if you are running a Linux operating system you will want to add your user to the `vboxusers` group so that the virtual machine can access your USB devices.  Run the following command:

    sudo usermod -a -G vboxusers $USER

Then **log out and log back in** to make sure the group change takes effect.

## Usage

First, clone this repository:

	git clone https://github.com/pichenettes/mutable-dev-environment.git

or download: 

	https://github.com/pichenettes/mutable-dev-environment/archive/master.zip

To start the VM, open a terminal in the `mutable-dev-environment` directory with the Vagrantfile and run:

    vagrant up

If this directory already has a VM created with the old x86 box, Vagrant cannot
convert it in place. Destroy and recreate it with `vagrant destroy` followed by
`vagrant up`; this removes data stored only inside the VM. The default firmware
checkout is in the host-shared project directory and is not removed.

The first time the VM is started, all tools will be downloaded, and the latest version of the code will be grabbed from github.  The process takes about 15 minutes, depending on the speed of your internet connection or computer.

The original Mutable Instruments sources and the SloBloLabs Parasites fork are
checked out side by side in `/vagrant/eurorack-modules` and `/vagrant/parasites`.
Both use the same VM and system libraries. The original sources use GCC 4.8.3;
the Parasites `stmlib` submodule defaults to the
`gcc-arm-none-eabi-5_4-2016q3` toolchain, whose compiler reports GCC 5.4.1.
The Mutable Instruments Beads makefiles require GCC 4.9. GCC 4.9 and 5.4.1
are installed alongside GCC 4.8.3 and run through QEMU on ARM64.

Then, you can log onto the virtual machine by running:

    vagrant ssh

Once in the virtual machine, you can try, for example, to compile Clouds' bootloader and code:

    mkdir -p build/clouds_bootloader build/clouds
    make -f clouds/bootloader/makefile hex
    make -f clouds/makefile

To write the firmware to the module with an Olimex ARM-USB-OCD-H JTAG adapter, use:

    make -f clouds/makefile upload

Using other programmers is of course possible, please see [Customization](#customization).

Or you can generate a .wav file for the built-in audio updater:

    make -f clouds/makefile wav

The firmware update file will be put in `build/clouds/clouds.wav`.

To build the same Clouds targets from Parasites, switch to its checkout and run:

    cd /vagrant/parasites
    mkdir -p build/clouds_bootloader build/clouds
    make -f clouds/bootloader/makefile hex
    make -f clouds/makefile

To build every module application and each available bootloader, run the
build script on the corresponding checkout. For each module it builds the
application HEX and, when the module makefile has a `wav` target, the WAV
firmware update file for the built-in audio updater. It then builds each
bootloader. It creates each build directory before invoking make, stops if a
build fails, and accepts either `makefile` or `makefile.mk` entrypoint names. The
`avrlib` and `avrlibx` makefile fragments are included by module makefiles and
are not standalone firmware targets.

In the original Mutable Instruments checkout:

    /vagrant/ci/build-all.sh /vagrant/eurorack-modules

In the Parasites checkout:

    /vagrant/ci/build-all.sh /vagrant/parasites

The results are in `build/<module>/` (application: `.hex`, `.elf`, `.bin`,
`.map`, `.wav`) and `build/<module>_bootloader/` (bootloader). The script does
not upload firmware. To build only the HEX files without the WAV step, use the
plain `make -f <module>/makefile` commands shown above.

Once you're done with your hacking session, you can leave the VM terminal with:

    exit

The virtual machine continues running and can be reaccessed with `vagrant ssh`. It can also be suspended with `vagrant suspend`, halted with `vagrant halt`, and completely destroyed with `vagrant destroy`.  Note that with this last command, you might lose any files you have created inside the VM's disk image!

## Publishing firmware as GitHub releases

The workflow [.github/workflows/release.yml](.github/workflows/release.yml)
builds both source trees on a GitHub-hosted Ubuntu 22.04 runner (no VM) with the
same pinned toolchains as the Vagrant environment (installed by
[ci/install-toolchains.sh](ci/install-toolchains.sh)), then attaches
`eurorack-original.zip`, `parasites.zip` and `SHA256SUMS` to a release. Each zip
holds the `.hex`, `.elf`, `.bin`, `.map` and, for every module whose makefile has a
`wav` target, the `.wav` audio-update file, for the applications and bootloaders.
It also contains `NOTICE.txt` (source commit, licenses, no-warranty and
"unofficial build" statement, and the source-code offer required by the GPL for
Branches, Edges and Grids) and a `LICENSES/` folder with the license texts of the
firmware and the bundled third-party code.

Neither upstream repository has version numbers or tags, so releases are named
after the build date: `vYYYY-MM-DD` (for example `v2026-11-24`; add a suffix such
as `v2026-11-24-2` for a second release on the same day). The release notes list
the exact source commits that were built.

* Push a tag to build and publish: `git tag v2026-11-24 && git push origin v2026-11-24`.
* Or run the workflow manually (Actions tab, or
  `gh workflow run release.yml --ref master -f publish_tag=v2026-11-24`) and choose the
  `eurorack`/`parasites` refs to build. Give a `publish_tag` to create the
  release (the tag is created if it does not exist yet), or leave it empty for a
  dry run.

Where to find the files:

* **Releases page** (public, permanent): only runs with a tag or `publish_tag`
  publish here, as `eurorack-original.zip`, `parasites.zip` and `SHA256SUMS`.
* **Workflow run page, "Artifacts"** (dry runs): the same two zips, but only for
  people who are signed in to GitHub with access to the repository, and they are
  deleted after 90 days.

The same build can be run inside the VM with
`/vagrant/ci/build-all.sh /vagrant/parasites` (or `/vagrant/eurorack-modules`).

## Moving files between the VM and the host

Both source checkouts (`eurorack-modules` and `parasites`) are installed in the
`/vagrant` directory, which is shared between the VM and the host. You can use
any text editor on the host to modify them. Any file can be transferred between
the VM and the host by copying it in this location.

If you prefer working in a more self-contained environment and leave your host directory clean, you can comment the line `CODE_DIRECTORY=/vagrant` and uncomment the line `CODE_DIRECTORY=/home/vagrant` before setting up the VM.  The code will not be installed in the shared directory, and will be accessible only from within the VM.

## USB issues

To pass through USB devices from your real machine to the virtual machine, consult the [VirtualBox USB documentation](https://www.virtualbox.org/manual/ch03.html#idp96037808).

## <a name=#customization></a>Customization

### Using a different programmer
To use a programmer other than the default (AVR ISP mkII, ARM-USB-OCD-H) it is no longer necessary to edit the makefiles. Instead, the programmer can be set in the shell for the current session, e.g.

	export PGM_INTERFACE=stlink-v2
	export PGM_INTERFACE_TYPE=hla

for ARM projects using a JTAG adapter. Similarly for AVR projects, you can use

	export PROGRAMMER=stk500
	export PROGRAMMER_PORT=/dev/tty.usbserial-xxxxxxxx

Any further calls to `make` will then automatically use these settings. To make them permanent, add the exports to the end of `~/.bashrc`.

See [stmlib/makefile.inc](https://github.com/pichenettes/stmlib/blob/master/makefile.inc#L29) and [avrlib/makefile.mk](https://github.com/pichenettes/avril/blob/master/makefile.mk#L16) for more options that can be customized.

Another way (e.g. to test if settings are correct) is to just specify the value in the call to `make`:

	PGM_INTERFACE=ftdi/olimex-arm-usb-tiny-h make -f braids/makefile upload

### Custom repository URL
If you want to build code from your own github fork, you can specify the repository to clone when you create the VM via the `USER_GITHUB_URL` environment variable, e.g.

	USER_GITHUB_URL=https://github.com/<username>/eurorack.git vagrant up

The Mutable Instruments' repository is automatically added as the git remote `pichenettes`.