{ pkgs, solidcraft, nix-ros-overlay, ros2-elastic-dashboard, ... }:
let
  rosPkgs = nix-ros-overlay.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  ros = rosPkgs.rosPackages.lyrical;
  # Puts an image on the clipboard as PNG and BMP (Wine programs paste the BMP).
  copyImage = pkgs.callPackage ./copy-image { };
  # Antigravity opens OAuth pages through xdg-open. Put an app-local shim first in PATH so only
  # Antigravity sends web URLs to Firefox; other apps keep the system's Zen default.
  antigravityXdgOpen = pkgs.writeShellScriptBin "xdg-open" ''
    case "$1" in
      http://*|https://*) exec ${pkgs.firefox}/bin/firefox "$@" ;;
      *) exec ${pkgs.xdg-utils}/bin/xdg-open "$@" ;;
    esac
  '';
  antigravityFirefox = pkgs.writeShellScriptBin "antigravity-firefox" ''
    export BROWSER=${pkgs.firefox}/bin/firefox
    export PATH="${antigravityXdgOpen}/bin:$PATH"
    exec ${pkgs.antigravity}/bin/antigravity "$@"
  '';
in
{

  # User-level GUI applications.
  home.packages = with pkgs; [
    kdePackages.kate
    vscode
    # Rust toolchain and editor integration.
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    antigravity
    antigravityFirefox
    brave
    spotify
    vlc
    putty
    solidcraft.packages.${pkgs.stdenv.hostPlatform.system}.solidcraft
    (ros.buildEnv { paths = [ ros.desktop ]; })
    rosPkgs.colcon
    ros2-elastic-dashboard.packages.${pkgs.stdenv.hostPlatform.system}.default
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

  xdg.desktopEntries = {
    ros2-elastic-dashboard = {
      name = "ROS 2 Elastic Dashboard";
      exec = "ros2_elastic_dashboard";
      categories = [ "Development" ];
      terminal = false;
    };
    antigravity = {
      name = "Antigravity";
      exec = "antigravity-firefox %F";
      icon = "antigravity";
      comment = "Code Editing. Redefined.";
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      terminal = false;
    };
  };

}
