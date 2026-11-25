{ pkgs, ... }:

let
  buildroot = import ../packages/buildroot.nix { inherit pkgs; };
in
{
  environment.systemPackages = [ buildroot ];
  # Foreign static executables can run directly through QEMU user mode.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];
}