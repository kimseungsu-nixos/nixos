{ config, lib, pkgs, ... }:

{
  imports = [
    ./home/niri.nix
    ./home/fcitx5.nix
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

  # Use Zen as the system-wide browser.
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    policies.Preferences = {
      "zen.view.use-single-toolbar" = { Value = false; Status = "user"; };
      "zen.view.compact.enable-at-startup" = { Value = true; Status = "user"; };
      "zen.view.compact.hide-toolbar" = { Value = true; Status = "user"; };
      "zen.view.compact.hide-tabbar" = { Value = false; Status = "user"; };
    };
  };

  programs.noctalia = {
    enable = true;
    settings = {
      shell = {
        font_family = "Pretendard";
        corner_radius_scale = 1.0;
        polkit_agent = true;
        panel = {
          transparency_mode = "soft";
          borders = true;
          shadow = true;
        };
      };
      bar.main = {
        position = "top";
        thickness = 34;
        background_opacity = 0.94;
        compositor_blur = true;
        radius = 11;
        margin_ends = 18;
        margin_edge = 8;
        padding = 12;
        widget_spacing = 8;
        start = [ "launcher" "workspaces" ];
        center = [ "clock" ];
        end = [ "media" "tray" "network" "battery" "notifications" "displays" "control-center" "session" ];
      };
      widget.displays = {
        type = "raycursive/niri-displays:bar";
        show_resolution = false;
      };
      plugins.enabled = [ "raycursive/niri-displays" ];
      plugin_settings."raycursive/niri-displays" = {
        panel_placement = "floating";
        panel_position = "center";
      };
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Nord";
      };
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        fill_color = "#2e3440";
        transition = [ "fade" ];
        default.path = "${./files/blue-hour.jpg}";
      };
    };
  };

  # Noctalia's state can override the declared wallpaper. Drop only its old bundled
  # selection so the new default is visible on this installation.
  home.activation.unsetBundledNoctaliaWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings=${lib.escapeShellArg "${config.xdg.stateHome}/noctalia/settings.toml"}
    if [[ -f "$settings" && ! -v DRY_RUN ]]; then
      updated=$(mktemp "$settings.XXXXXX")
      ${lib.getExe pkgs.gawk} '
        /^\[/ { wallpaper = /^\[wallpaper\.(default|last)\]$/ }
        wallpaper && /^path = "\/nix\/store\/[^/]+-noctalia-[^/]+\/share\/noctalia\/assets\/noctalia-wallpaper\.png"$/ { next }
        { print }
      ' "$settings" > "$updated"
      if ! cmp -s "$settings" "$updated"; then
        chmod --reference="$settings" "$updated"
        mv -f "$updated" "$settings"
      else
        rm -f "$updated"
      fi
    fi
  '';

  # Open folders in Nautilus. mimeapps.list stays writable (apps register URL handlers in it),
  # so the default is set in place instead of through xdg.mimeApps.
  home.activation.defaultFileManager = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.Nautilus.desktop inode/directory
  '';

  home.activation.defaultFileApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.FileRoller.desktop \
      application/zip application/x-7z-compressed application/vnd.rar application/x-rar \
      application/x-tar application/gzip application/x-compressed-tar application/x-bzip2 \
      application/x-bzip-compressed-tar application/x-bzip2-compressed-tar \
      application/x-xz application/x-xz-compressed-tar application/zstd \
      application/x-zstd-compressed-tar application/x-raw-disk-image-xz-compressed

    $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default org.gnome.Loupe.desktop \
      image/jpeg image/png image/apng image/webp image/gif image/bmp image/tiff \
      image/svg+xml image/svg+xml-compressed image/avif image/heic image/jxl

    # Disk Image Mounter attaches images read-only. Keep the legacy ISO MIME key in sync.
    $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default gnome-disk-image-mounter.desktop \
      application/vnd.efi.iso application/x-cd-image application/x-iso9660-image \
      application/vnd.efi.img application/x-raw-disk-image
  '';

  # Dark Adwaita with blue Papirus folders and a matching cursor.
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
        accent = "blue";
      };
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 28;
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

  xdg.configFile."ghostty/config".text = ''
    theme = Nord
    font-family = JetBrainsMono Nerd Font
    font-size = 11
    window-decoration = none
    window-theme = ghostty
    gtk-tabs-location = bottom
    window-padding-x = 10
    window-padding-y = 8
    # Nautilus launches Ghostty in the selected folder via its process working directory.
    gtk-single-instance = false
    working-directory = inherit
    # Let terminal applications receive Ctrl+Enter instead of entering fullscreen.
    keybind = ctrl+enter=unbind
  '';
}
