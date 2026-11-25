{ pkgs }:

let
  version = "2026.05.3";
  sourceName = "buildroot-${version}";
  src = pkgs.fetchurl {
    url = "https://buildroot.org/downloads/${sourceName}.tar.xz";
    hash = "sha256-9D8WJwgqRYSPcwg7O41Z8yu0x3pEmo6tiiofkYSd6gA=";
  };
  workspace = "\${BUILDROOT_WORKSPACE:-$HOME/buildroot-workspace}";
  launcher = pkgs.writeShellScript "buildroot-launcher" ''
    set -euo pipefail

    if (( EUID == 0 )); then
      echo 'Buildroot must run as a regular user, not root.' >&2
      exit 1
    fi
    if [[ ''${1:-} == --shell ]]; then
      shift
      exec /bin/bash --noprofile --norc "$@"
    fi

    workspace="${workspace}"
    source="$workspace/${sourceName}"
    export BR2_DL_DIR="''${BR2_DL_DIR:-$HOME/.buildroot-dl}"
    # Buildroot resolves the cache path from the source tree, not the caller.
    BR2_DL_DIR=$(realpath -m -- "$BR2_DL_DIR")
    mkdir -p -- "$workspace" "$BR2_DL_DIR"

    if [[ ! -d $source ]]; then
      (
        flock 9
        if [[ ! -d $source ]]; then
          staging=$(mktemp -d -- "$workspace/.${sourceName}.XXXXXXXX")
          trap 'rm -rf -- "$staging"' EXIT
          tar -xf ${src} -C "$staging"
          mv -T -- "$staging/${sourceName}" "$source"
        fi
      ) 9>"$workspace/.${sourceName}.lock"
    fi

    cd -- "$source"
    exec make "$@"
  '';

  # Upstream requires /usr/bin/file; external toolchains also expect the FHS
  # ELF loader. A list of runtimeInputs on its own provides neither path.
  buildroot = pkgs.buildFHSEnv {
    name = "buildroot";
    runScript = launcher;
    targetPkgs = p: with p; [
      bc
      binutils
      bison
      cacert
      cmake
      cpio
      curl
      dtc
      e2fsprogs
      fakeroot
      file
      flex
      gcc
      git
      gnumake
      lz4
      ncurses
      openssh
      openssl
      patch
      perl
      pkg-config
      python3
      rsync
      unzip
      util-linux
      wget
      which
      zlib
      zstd
    ];
    extraOutputsToInstall = [ "dev" ];
  };

  runBoard = name: command: pkgs.writeShellApplication {
    inherit name;
    text = ''
      cd -- "''${1:-${workspace}/${sourceName}/output/images}"
      exec ${pkgs.qemu}/bin/${command}
    '';
  };

  runRiscv64Virt = runBoard "run-qemu-riscv64-virt" ''
    qemu-system-riscv64 -M virt -m 2G \
      -bios fw_jump.bin -kernel Image -append 'rootwait root=/dev/vda ro' \
      -drive file=rootfs.ext2,format=raw \
      -netdev user,id=net0 -device virtio-net-device,netdev=net0 -nographic
  '';

  runAarch64Virt = runBoard "run-qemu-aarch64-virt" ''
    qemu-system-aarch64 -M virt -cpu cortex-a53 -m 2G -smp 1 \
      -kernel Image -append 'rootwait root=/dev/vda console=ttyAMA0' \
      -drive file=rootfs.ext4,if=none,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 \
      -netdev user,id=eth0 -device virtio-net-device,netdev=eth0 -nographic
  '';

  runTarget = name: arch: pkgs.writeShellApplication {
    inherit name;
    text = ''
      exec ${pkgs.qemu-user}/bin/qemu-${arch} "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "buildroot-dev-${version}";
  paths = [
    buildroot
    runRiscv64Virt
    runAarch64Virt
    (runTarget "run-target" "aarch64")
    (runTarget "run-target-riscv64" "riscv64")
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
  meta.mainProgram = "buildroot";
}
