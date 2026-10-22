{ pkgs, solidcraft, frc2023-nix, ... }:
let
  # Puts an image on the clipboard as PNG and BMP (Wine programs paste the BMP).
  copyImage = pkgs.callPackage ./copy-image { };
in
{

  # User-level GUI applications.
  home.packages = with pkgs; [
    kdePackages.kate
    vscode
    brave
    spotify
    vlc
    putty
    solidcraft.packages.${pkgs.stdenv.hostPlatform.system}.solidcraft
    # FRC 2026 desktop tools.
    advantagescope
    choreo
    elastic-dashboard
    pathplanner
    wpilib.datalogtool
    wpilib.glass
    wpilib.outlineviewer
    wpilib.sysid
    wpilib.wpical
    wpilib.wpilib-utility
    # Keep these legacy FRC 2023 tools alongside the 2026 suite.
    frc2023-nix.packages.${pkgs.stdenv.hostPlatform.system}.pathweaver
    frc2023-nix.packages.${pkgs.stdenv.hostPlatform.system}.roborioteamnumbersetter
    frc2023-nix.packages.${pkgs.stdenv.hostPlatform.system}.robotbuilder
    frc2023-nix.packages.${pkgs.stdenv.hostPlatform.system}.shuffleboard
    frc2023-nix.packages.${pkgs.stdenv.hostPlatform.system}.smartdashboard
    kicad
    arduino-ide
    godot    # Godot 4 game engine
    xwayland-satellite
    alsa-utils
    brightnessctl
    ffmpeg
    mpc
    wireplumber
    grim
    slurp
    wl-clipboard
    copyImage
    (writeShellScriptBin "screenshot-region" ''
      set -eu
      output_dir="$HOME/Pictures/Screenshots"
      mkdir -p "$output_dir"
      geometry="$(slurp)"
      [ -n "$geometry" ] || exit 0
      image="$output_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
      grim -g "$geometry" "$image"
      ${copyImage}/bin/copy-image "$image"
    '')
  ];

}
