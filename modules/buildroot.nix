{ pkgs, ... }:

let
  buildroot = import ../packages/buildroot.nix { inherit pkgs; };
in
{
  environment.systemPackages = [ buildroot ] ++ (with pkgs; [
    file
    bc
    flex
    bison
    pkg-config
    cmake
    ncurses
    ncurses.dev
    openssl
    openssl.dev
  ]);
  # Buildroot's host checks use this absolute path even when file is on PATH.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/file - - - - ${pkgs.file}/bin/file"
  ];
  # Foreign static executables can run directly through QEMU user mode.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];
}
