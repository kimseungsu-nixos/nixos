{ pkgs, solidcraft, ... }:
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

  # Give WPILib tools searchable launcher names; upstream desktop files use only short tool names
  # such as "Glass" and therefore do not appear when searching for "wpilib".
  xdg.desktopEntries = {
    wpilib-2026-datalogtool = {
      name = "WPILib 2026 DataLogTool";
      exec = "datalogtool";
      icon = "DataLogTool";
      categories = [ "Development" "Education" ];
    };
    wpilib-2026-glass = {
      name = "WPILib 2026 Glass";
      exec = "glass";
      icon = "Glass";
      categories = [ "Development" "Education" ];
    };
    wpilib-2026-outlineviewer = {
      name = "WPILib 2026 OutlineViewer";
      exec = "outlineviewer";
      icon = "OutlineViewer";
      categories = [ "Development" "Education" ];
    };
    wpilib-2026-sysid = {
      name = "WPILib 2026 SysId";
      exec = "sysid";
      icon = "SysId";
      categories = [ "Development" "Education" ];
    };
    wpilib-2026-wpical = {
      name = "WPILib 2026 WPICal";
      exec = "wpical";
      icon = "wpical";
      categories = [ "Development" "Education" ];
    };
    wpilib-2026-utility = {
      name = "WPILib 2026 Utility";
      exec = "wpilib-utility";
      icon = "wpilib-utility";
      categories = [ "Development" "Education" ];
    };
  };

}
