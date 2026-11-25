# Host configuration for linux. The settings live in ./modules.
{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/system.nix
    ./modules/nix.nix
    ./modules/resources.nix
    ./modules/hotspot.nix
    ./modules/desktop.nix
    ./modules/apps.nix
    ./modules/buildroot.nix
    ./modules/theme.nix
    ./modules/vbt.nix
  ];
}
