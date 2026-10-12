{ pkgs, lib, ... }:

let
  # 26.05 ships rpi-imager 2.0.9, which crashes at startup (QML "QQmlApplicationEngine failed
  # to load component": missing Material import, nixpkgs#529793). Fixed upstream after 2.0.9;
  # drop the patch when nixpkgs has >= 2.0.10.
  rpiImagerPatched = pkgs.rpi-imager.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchpatch {
        name = "add-material-import.patch";
        url = "https://github.com/raspberrypi/rpi-imager/commit/a4a2d3f402c20daf76a15d18acb22f6be6810b35.patch";
        hash = "sha256-n0AwancP8oY/sUUQtmuznfgeYkf+eXrHC1uzx41OclE=";
      })
    ];
  });

  # Imager has to write raw block devices, so it always starts as root: `rpi-imager` (and the
  # menu entry, whose Exec is plain `rpi-imager`) goes through pkexec, passing the Wayland
  # session variables on so the root process can show its window.
  rpiImager = pkgs.symlinkJoin {
    name = "rpi-imager-root";
    paths = [ rpiImagerPatched ];
    postBuild = ''
      rm $out/bin/rpi-imager
      cat > $out/bin/rpi-imager <<'EOF'
      #!${pkgs.runtimeShell}
      if [ "$(id -u)" = 0 ]; then
        exec ${rpiImagerPatched}/bin/rpi-imager "$@"
      fi
      exec /run/wrappers/bin/pkexec env \
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" \
        ${rpiImagerPatched}/bin/rpi-imager "$@"
      EOF
      chmod +x $out/bin/rpi-imager
    '';
  };
in
{
  programs.firefox.enable = true;

  # ChatGPT Community (menu entry "ChatGPT Community", command codex-desktop). Unfree wrapper.
  programs.codexDesktopLinux.enable = true;

  # Claude Desktop (official Linux beta, unfree).
  programs.claude-desktop.enable = true;

  # OBS Studio (screen recording / streaming), with the virtual camera module.
  programs.obs-studio.enable = true;

  # Studica Hardware Manager. users get added to the dialout group (re-login needed).
  programs.studica-hardware-manager = {
    enable = true;
    users = [ "linux" ];
  };

  # Studica Titan Config & Update App (udev rules for 0483:5740 / df11, dfu-util).
  programs.titan-config.enable = true;

  # podman/distrobox for containers (WPILib VMX 2020 itself runs natively, see home/wpilib-vmx.nix).
  # hardware.graphics exposes Mesa at /run/opengl-driver, which distrobox bind-mounts into a container.
  virtualisation.podman.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # OBS VA-API encoding and decoding on the Intel Iris Xe / Arc GPUs.
    extraPackages = [ pkgs.intel-media-driver ];
  };

  # Terminal: foot (colours in home.nix, Mod+Return in home/niri.nix).
  # Apps with Terminal=true open in foot instead of falling back to xterm: Noctalia's
  # launcher reads $TERMINAL, GLib/GIO apps use xdg-terminal-exec.
  environment.sessionVariables.TERMINAL = "foot";
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "foot.desktop" ];
  };
  # services.xserver.enable pulls in xterm by default.
  services.xserver.excludePackages = [ pkgs.xterm ];

  # File manager: Thunar with removable-media, archive and thumbnail support
  # (mounts through the UDisks/GVFS services in modules/desktop.nix).
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [ thunar-volman thunar-archive-plugin ];
  };
  services.tumbler.enable = true;
  # Thunar's archive menu (extract here, compress...) runs Xarchiver through the .tap file it ships.
  environment.pathsToLink = [ "/libexec/thunar-archive-plugin" ];

  # Ventoy is flagged insecure in nixpkgs: its prebuilt boot images and tools are binary blobs
  # that cannot be audited (https://github.com/NixOS/nixpkgs/issues/404663). Only Ventoy is
  # allowed through; any other insecure package is still refused.
  nixpkgs.config.allowInsecurePredicate = pkg: lib.hasPrefix "ventoy" (lib.getName pkg);

  # CLI tools and anything the system itself needs. GUI apps live in
  # home/packages.nix.
  environment.systemPackages = with pkgs; [
    wget
    git
    gh
    btop
    distrobox
    nodejs
    python3
    rpiImager   # Raspberry Pi Imager, always as root
    ventoy-full-gtk  # bootable USB creator (run with sudo or via polkit)
    # Archives: Xarchiver is the GUI; the others are what it calls. unar copes with legacy Korean
    # (CP949) file names in zip files, which 7-Zip and unzip turn into garbage.
    xarchiver
    zip
    unzip
    p7zip
    unrar
    unar
    ntfs3g
    dosfstools
    exfatprogs
    # Thunar's "Open Terminal Here" goes through exo-open, which needs xfce4-mime-helper.
    # Only that binary is linked in, not the rest of the Xfce settings apps.
    (runCommand "xfce4-mime-helper" { } ''
      mkdir -p $out/bin
      ln -s ${xfce4-settings}/bin/xfce4-mime-helper $out/bin/
    '')
  ];
}
