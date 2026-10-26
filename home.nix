{ lib, pkgs, ... }:

{
  imports = [
    ./home/niri.nix
    ./home/packages.nix
  ];

  home.stateVersion = "26.05";

  # Seed the OBS profile and scene collection once on new installations. Copying only missing
  # files keeps OBS settings writable and preserves changes made later in the app.
  home.activation.seedObsStudioConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile_dir="$HOME/.config/obs-studio/basic/profiles/Untitled"
    scene_dir="$HOME/.config/obs-studio/basic/scenes"

    if [ ! -e "$profile_dir/basic.ini" ]; then
      $DRY_RUN_CMD install -Dm644 "${./config/obs-studio/profiles/Untitled/basic.ini}" "$profile_dir/basic.ini"
    fi
    if [ ! -e "$profile_dir/streamEncoder.json" ]; then
      $DRY_RUN_CMD install -Dm644 "${./config/obs-studio/profiles/Untitled/streamEncoder.json}" "$profile_dir/streamEncoder.json"
    fi
    if [ ! -e "$scene_dir/Untitled.json" ]; then
      $DRY_RUN_CMD install -Dm644 "${./config/obs-studio/scenes/Untitled.json}" "$scene_dir/Untitled.json"
    fi
  '';

  # Use Zen for browser links.
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  programs.noctalia = {
    enable = true;
    settings = {
      shell = {
        font_family = "Pretendard";
        corner_radius_scale = 1.15;
        polkit_agent = true;
        panel = {
          transparency_mode = "glass";
          borders = false;
          shadow = true;
        };
      };
      bar.main = {
        position = "top";
        thickness = 40;
        background_opacity = 0.92;
        compositor_blur = true;
        radius = 14;
        margin_ends = 220;
        margin_edge = 10;
        padding = 14;
        widget_spacing = 8;
        start = [ "launcher" "workspaces" ];
        center = [ "clock" ];
        end = [ "media" "tray" "network" "bluetooth" "volume" "battery" "notifications" "displays" "control-center" "session" ];
      };
      widget.displays = {
        type = "raycursive/niri-displays:bar";
        show_resolution = true;
      };
      plugins.enabled = [ "raycursive/niri-displays" ];
      plugin_settings."raycursive/niri-displays" = {
        panel_placement = "floating";
        panel_position = "center";
      };
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
      wallpaper.enabled = false;
    };
  };

  # Open folders in Thunar. mimeapps.list stays writable (apps register URL handlers in it),
  # so the default is set in place instead of through xdg.mimeApps.
  home.activation.defaultFileManager = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default thunar.desktop inode/directory
  '';

  # Archives open in Xarchiver (zip, 7z, rar, tar and friends).
  home.activation.defaultArchiver = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for type in application/zip application/x-7z-compressed application/vnd.rar application/x-rar \
        application/x-tar application/gzip application/x-compressed-tar application/x-bzip2 \
        application/x-bzip-compressed-tar application/x-xz application/x-xz-compressed-tar \
        application/zstd application/x-zstd-compressed-tar application/x-iso9660-image; do
      $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default xarchiver.desktop "$type"
    done
  '';

  # foot for Thunar's "Open Terminal Here".
  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=foot
  '';
  # Xfce ships no helper entry for foot. foot is started detached (setsid -f): otherwise
  # xfce4-mime-helper waits on it and Thunar reports an error once the terminal is closed.
  xdg.dataFile."xfce4/helpers/foot.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=X-XFCE-Helper
    Icon=foot
    Name=foot
    StartupNotify=false
    X-XFCE-Binaries=foot;
    X-XFCE-Category=TerminalEmulator
    X-XFCE-Commands=${pkgs.util-linux}/bin/setsid -f %B;
    X-XFCE-CommandsWithParameter=${pkgs.util-linux}/bin/setsid -f %B -e %s;
  '';

  # GTK look for Thunar and other GTK apps: dark adw-gtk3 with Papirus icons using
  # Catppuccin Mocha mauve folders (matching modules/theme.nix).
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "mauve";
      };
    };
    cursorTheme = {
      name = "catppuccin-mocha-mauve-cursors";
      size = 24;
    };
    font = {
      name = "Pretendard";
      size = 10;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    # libadwaita (GTK4) apps ignore GTK themes; keep them on their own dark style.
    gtk4.theme = null;
  };
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # foot with the Catppuccin Mocha palette.
  programs.foot = {
    enable = true;
    settings = {
      main.font = "JetBrainsMono Nerd Font:size=11";
      scrollback.lines = 100000;
      csd.preferred = "none";
      colors-dark = {
        background = "1e1e2e";
        foreground = "cdd6f4";
        cursor = "1e1e2e f5e0dc";
        selection-foreground = "cdd6f4";
        selection-background = "585b70";
        regular0 = "45475a";
        regular1 = "f38ba8";
        regular2 = "a6e3a1";
        regular3 = "f9e2af";
        regular4 = "89b4fa";
        regular5 = "f5c2e7";
        regular6 = "94e2d5";
        regular7 = "bac2de";
        bright0 = "585b70";
        bright1 = "f38ba8";
        bright2 = "a6e3a1";
        bright3 = "f9e2af";
        bright4 = "89b4fa";
        bright5 = "f5c2e7";
        bright6 = "94e2d5";
        bright7 = "a6adc8";
      };
    };
  };
}
