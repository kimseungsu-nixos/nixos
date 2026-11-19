{ pkgs, rosEnv, colconRos2, ... }:
let
  # Puts an image on the clipboard as PNG and BMP (Wine programs paste the BMP).
  copyImage = pkgs.callPackage ./copy-image { };
in
{
  # Bash loads the ROS 2 completion hook on the first completion request.
  xdg.dataFile."bash-completion/completions/ros2".source =
    "${rosEnv}/share/ros2cli/environment/ros2-argcomplete.bash";

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
    brave
    spotify
    vlc
    rosEnv
    colconRos2
    # Toolchain for building ROS packages with colcon and CMake.
    cmake
    gnumake
    stdenv.cc
    kicad
    arduino-ide
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
