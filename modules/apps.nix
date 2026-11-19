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
  # VS Code >= 1.122 moved ripgrep into a platform-specific directory.
  # Keep the 26.05 package's system-ripgrep replacement working until its
  # generic builder catches up; the substitution is a no-op once fixed upstream.
  nixpkgs.overlays = [
    (_final: prev: {
      vscode = prev.vscode.overrideAttrs (old: {
        postPatch = if lib.versionAtLeast old.version "1.122.0" then
          lib.replaceStrings
            [ "@vscode/ripgrep/bin/rg" ]
            [ "@vscode/ripgrep-universal/bin/linux-x64/rg" ]
            old.postPatch
        else old.postPatch;
      });
    })
  ];

  programs.firefox.enable = true;

  # Claude Desktop (official Linux beta, unfree).
  programs.claude-desktop.enable = true;

  # Oh My Pi terminal coding agent (command: omp).
  programs.omp.enable = true;

  # OBS Studio (screen recording / streaming), with the virtual camera module.
  programs.obs-studio.enable = true;

  # Studica Titan Config & Update App (udev rules for 0483:5740 / df11, dfu-util).
  programs.titan-config.enable = true;

  # Register the DreamSourceLab USB rules bundled with DSView.
  services.udev.packages = [ pkgs.dsview ];

  # podman/distrobox for containers (WPILib VMX 2020 itself runs natively, see home/wpilib-vmx.nix).
  # hardware.graphics exposes Mesa at /run/opengl-driver, which distrobox bind-mounts into a container.
  virtualisation.podman.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # OBS VA-API encoding and decoding on the Intel Iris Xe / Arc GPUs.
    extraPackages = [ pkgs.intel-media-driver ];
  };

  # Noctalia reads $TERMINAL; GLib/GIO apps use xdg-terminal-exec.
  environment.sessionVariables.TERMINAL = "ghostty";
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "com.mitchellh.ghostty.desktop" ];
  };
  # services.xserver.enable pulls in xterm by default.
  services.xserver.excludePackages = [ pkgs.xterm ];

  programs.gnome-disks.enable = true;
  # Nautilus uses UDisks/GVFS from modules/desktop.nix for removable media.
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };

  services.flatpak.enable = true;
  # Remove Sober from machines that ran the previous system installation job.
  systemd.services.remove-sober = {
    description = "Uninstall the legacy system Flatpak installation of Sober";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/remove-sober/done";
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "remove-sober";
    };
    script = ''
      if [ -e /var/lib/flatpak/app/org.vinegarhq.Sober/current/active ]; then
        ${lib.getExe pkgs.flatpak} uninstall --system --noninteractive --assumeyes app/org.vinegarhq.Sober
      fi
      touch "$STATE_DIRECTORY/done"
    '';
  };

  # Ventoy is flagged insecure in nixpkgs: its prebuilt boot images and tools are binary blobs
  # that cannot be audited (https://github.com/NixOS/nixpkgs/issues/404663). Only Ventoy is
  # allowed through; any other insecure package is still refused.
  nixpkgs.config.allowInsecurePredicate = pkg: lib.hasPrefix "ventoy" (lib.getName pkg);

  # CLI tools and desktop file handlers. Other GUI apps live in home/packages.nix.
  environment.systemPackages = with pkgs; [
    wget
    git
    gh
    btop
    ghostty
    distrobox
    nodejs
    python3
    dsview
    rpiImager   # Raspberry Pi Imager, always as root
    ventoy-full-gtk  # bootable USB creator (run with sudo or via polkit)
    nautilus
    file-roller
    loupe
    # Official 7-Zip backend. Keep unar for legacy Korean (CP949) ZIP filenames.
    _7zz
    zip
    unzip
    p7zip
    unrar
    unar
    ntfs3g
    dosfstools
    exfatprogs
  ];
}
