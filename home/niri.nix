{ pkgs, ... }:

let
  niriConfig = pkgs.writeText "niri-config.kdl" ''
    input {
        keyboard {
            xkb {
                layout "kr"
                variant "kr104"
                options "korean:ralt_hangul,korean:rctrl_hanja"
            }
        }
        touchpad {
            natural-scroll
        }
        mouse {
            accel-profile "flat"
            accel-speed 0.0
        }
    }

    cursor {
        xcursor-theme "catppuccin-mocha-mauve-cursors"
        xcursor-size 24
    }

    // Ask apps to drop their own title bars. Without this, Chromium/Electron apps on
    // Wayland (Spotify, VS Code, Brave, ...) draw Chromium's unstyled fallback frame.
    prefer-no-csd

    environment {
        QT_QPA_PLATFORM "wayland"
        NIXOS_OZONE_WL "1"
    }

    // Let Niri launch Xwayland on demand for X11 programs (Wine, KakaoTalk, ...).
    xwayland-satellite {
        path "${pkgs.xwayland-satellite}/bin/xwayland-satellite"
    }

    // The monitor lists 3440x1440@100 next to its default 50 Hz mode; at 50 Hz the pointer and
    // every window trail by a visible fraction of a second.
    output "HDMI-A-1" {
        mode "3440x1440@100.000"
    }

    spawn-at-startup "noctalia"

    // Round and clip every window to its geometry.
    window-rule {
        geometry-corner-radius 16
        clip-to-geometry true
    }

    window-rule {
        match app-id="dev.noctalia.Noctalia"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 900; }
    }

    // Keep KakaoTalk's main window in the normal layout, but let chat and settings
    // windows use their requested size instead of stretching them into a tiled column.
    window-rule {
        match app-id=r"^kakaotalk\.exe$"
        exclude title="^(카카오톡|KakaoTalk)$"
        open-floating true
        default-column-width {}
        default-window-height {}
    }

    // The tray bridge's container window (home/xembedsniproxy): invisible, never focused.
    window-rule {
        match app-id="^xembedsniproxy$"
        open-floating true
        open-focused false
        opacity 0.0
        // opacity 0 hides the content only: the border and rounded corners would still show
        // as a small ring in the corner.
        border { off; }
        focus-ring { off; }
        shadow { off; }
        geometry-corner-radius 0
        default-floating-position x=0 y=0 relative-to="bottom-right"
    }

    debug {
        honor-xdg-activation-with-invalid-serial
    }

    layout {
        gaps 8
        background-color "#1e1e2e"
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        border {
            width 2
            active-color "#cba6f7"
            inactive-color "#45475a"
        }
        focus-ring { off; }
    }

    overview {
        backdrop-color "#181825"
    }

    layer-rule {
        match namespace="^noctalia-"
        background-effect {
            xray false
        }
    }

    blur {
        passes 2
        offset 3.0
        saturation 1.0
    }

    binds {
        Mod+Return { spawn "foot"; }
        Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
        Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
        Mod+Comma { spawn-sh "noctalia msg settings-toggle"; }
        Mod+Shift+D { spawn-sh "noctalia msg panel-toggle raycursive/niri-displays:panel"; }
        Print { spawn "screenshot-region"; }
        Mod+Shift+S { spawn "screenshot-region"; }
        Alt+Tab { spawn-sh "noctalia msg window-switcher hold"; }
        Super+Alt+L { spawn "noctalia" "msg" "session" "lock"; }
        Mod+Q { close-window; }
        Mod+O { toggle-overview; }
        Mod+F { maximize-column; }
        Mod+V { toggle-window-floating; }
        Mod+R { switch-preset-column-width; }

        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+L { move-column-right; }

        Mod+Left { focus-column-left; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Down { move-window-down; }
        Mod+Shift+Up { move-window-up; }
        Mod+Shift+Right { move-column-right; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+Shift+1 { move-window-to-workspace 1; }
        Mod+Shift+2 { move-window-to-workspace 2; }
        Mod+Shift+3 { move-window-to-workspace 3; }
        Mod+Shift+4 { move-window-to-workspace 4; }
        Mod+Shift+5 { move-window-to-workspace 5; }
        Mod+Shift+6 { move-window-to-workspace 6; }
        Mod+Shift+7 { move-window-to-workspace 7; }
        Mod+Shift+8 { move-window-to-workspace 8; }
        Mod+Shift+9 { move-window-to-workspace 9; }

        Mod+Alt+Left { focus-monitor-left; }
        Mod+Alt+Right { focus-monitor-right; }
        Mod+Shift+Alt+Left { move-column-to-monitor-left; }
        Mod+Shift+Alt+Right { move-column-to-monitor-right; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "noctalia msg volume-up"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "noctalia msg volume-down"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn-sh "noctalia msg brightness-up"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn-sh "noctalia msg brightness-down"; }

        Mod+Shift+E { quit; }
    }
  '';
in
{
  xdg.configFile."niri/config.kdl".source = niriConfig;

  # Puts X11 (XEmbed) tray icons, e.g. KakaoTalk's under Wine, into Noctalia's tray.
  systemd.user.services.xembedsniproxy = {
    Unit = {
      Description = "XEmbed to StatusNotifierItem tray bridge";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.callPackage ./xembedsniproxy { }}/bin/xembedsniproxy";
      Environment = [ "QT_QPA_PLATFORM=xcb" ];
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
