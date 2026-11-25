{ lib, pkgs, ... }:

# Buildroot development environment. The upstream sources are fetched into the
# store once; `buildroot` unpacks them into a writable workspace and runs make
# there, because Buildroot writes into its own source tree and refuses to run as
# root. The QEMU runners below use the command lines from board/qemu/*/readme.txt.

let
  buildrootVersion = "2026.05.3";

  buildrootSrc = pkgs.fetchurl {
    url = "https://buildroot.org/downloads/buildroot-${buildrootVersion}.tar.xz";
    hash = "sha256-9D8WJwgqRYSPcwg7O41Z8yu0x3pEmo6tiiofkYSd6gA=";
    name = "buildroot-${buildrootVersion}.tar.xz";
  };

  workspace = "$HOME/buildroot-workspace";
  sourceTree = "${workspace}/buildroot-${buildrootVersion}";

  # The runners read the images of the last build; an explicit directory takes
  # precedence, so a kernel or rootfs from another board can be tested too.
  imageSelection = ''
    images="$1"
    if [ -z "$images" ]; then
      images="${sourceTree}/output/images"
    fi
  '';

  # Host tools Buildroot and its packages invoke while building. /usr/bin/file
  # and make are mandatory (support/dependencies/dependencies.sh); the rest
  # covers the common package selection: host gcc, cmake/meson, python,
  # openssl, and the download tools.
  hostPackages = with pkgs; [
    bc
    bison
    cmake
    curl
    dtc
    e2fsprogs
    file
    flex
    fakeroot
    gcc
    git
    gnumake
    gnused
    gnugrep
    gnutar
    gzip
    libyaml
    lz4
    lzo
    ncurses
    openssl
    patch
    perl
    pkg-config
    python3
    rsync
    unzip
    wget
    which
    xz
    zlib
    zstd
  ];

  buildroot = pkgs.writeShellApplication {
    name = "buildroot";
    runtimeInputs = hostPackages;
    text = ''
      set -eu

      mkdir -p "${workspace}" "$HOME/.buildroot-dl"

      # Buildroot writes into its own tree (and refuses to run as root), so the
      # store tarball is unpacked into a private workspace once.
      if [ ! -e "${sourceTree}" ]; then
        tar -C "${workspace}" -xf ${lib.escapeShellArg buildrootSrc}
      fi

      cd "${sourceTree}"
      exec make "$@"
    '';
  };

  runRiscv64Virt = pkgs.writeShellApplication {
    name = "run-qemu-riscv64-virt";
    runtimeInputs = [ pkgs.qemu ];
    text = ''
      set -eu
      ${imageSelection}
      cd "$images"
      exec ${pkgs.qemu}/bin/qemu-system-riscv64 -M virt -m 2G \
        -bios fw_jump.bin \
        -kernel Image \
        -append "rootwait root=/dev/vda ro" \
        -drive file=rootfs.ext2,format=raw \
        -netdev user,id=net0 -device virtio-net-device,netdev=net0 \
        -nographic
    '';
  };

  runAarch64Virt = pkgs.writeShellApplication {
    name = "run-qemu-aarch64-virt";
    runtimeInputs = [ pkgs.qemu ];
    text = ''
      set -eu
      ${imageSelection}
      cd "$images"
      exec ${pkgs.qemu}/bin/qemu-system-aarch64 -M virt -cpu cortex-a53 -m 2G -smp 1 \
        -kernel Image \
        -append "rootwait root=/dev/vda console=ttyAMA0" \
        -netdev user,id=eth0 -device virtio-net-device,netdev=eth0 \
        -drive file=rootfs.ext4,if=none,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 \
        -nographic
    '';
  };

  # Buildroot ships its own target toolchain; this one covers running a target
  # binary directly on this machine.
  runTarget = pkgs.writeShellApplication {
    name = "run-target";
    runtimeInputs = [ pkgs.qemu-user ];
    text = ''
      set -eu
      exec ${pkgs.qemu-user}/bin/qemu-aarch64 "$@"
    '';
  };
in
{
  environment.systemPackages = [
    buildroot
    runRiscv64Virt
    runAarch64Virt
    runTarget
  ] ++ (with pkgs; [
    qemu
    qemu-user
    gdb
    squashfs-tools-ng
    dosfstools
    mtools
    parted
    screen
    usbutils
    pciutils
  ]);

  # Target binaries (a rootfs built by Buildroot) run directly on the host, so a
  # package can be tested without booting the emulated board.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  # QEMU system emulation of the boards above needs /dev/kvm for usable speed,
  # which the user account already has through modules/system.nix.
}