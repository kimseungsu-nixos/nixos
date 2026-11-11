# NixOS

NixOS flake for the `linux` machine: niri (scrollable-tiling Wayland compositor) with the
Noctalia shell.

```bash
./scripts/rebuild.sh switch
```

## Layout

| Path | What |
| --- | --- |
| `flake.nix` | inputs (nixpkgs 26.05, home-manager, noctalia, hnc2020, nix-packages, ...) and the host |
| `configuration.nix` | imports the modules below |
| `modules/system.nix` | boot, network, locale, user, ssh, automatic Nix cleanup |
| `modules/desktop.nix` | niri session, keyboard, Korean input (kime), audio, Bluetooth, printing |
| `modules/apps.nix` | Hancom Office, Nautilus, podman/distrobox, CLI tools |
| `modules/theme.nix` | Catppuccin Mocha: login screen, cursor, fonts |
| `home.nix`, `home/` | home-manager: niri config (`niri.nix`), GTK theme and foot (`home.nix`), GUI apps (`packages.nix`), tray bridge (`xembedsniproxy/`), clipboard helper (`copy-image/`) |
| `hardware-configuration.nix` | generated for this machine |

## Notes

- `hnc2020` (Hancom Office) is a private repo fetched over HTTPS with the git
  credentials from `gh auth login`. The rebuild script updates the flake as your
  user before invoking `nixos-rebuild --sudo`; `./scripts/rebuild.sh build` builds
  without switching, while `./scripts/rebuild.sh switch` applies the system.
- ROS 2 Lyrical Desktop is installed in the user environment from `nix-ros-overlay`.
  The overlay keeps its tested nixpkgs input separate from the system channel.
- Old builds are cleaned up automatically: a weekly `nix.gc` deletes
  generations older than 7 days and `/boot` keeps the last 5.
- Screenshots (`Print`, `Mod+Shift+S`) go to `~/Pictures/Screenshots` and onto the clipboard as
  PNG and BMP plus the file itself (`home/copy-image`), so they paste into Wine programs and
  file managers too.
- Kime's XIM bridge runs as `kime-xim.service` (`home/kime.nix`), separately from its Wayland
  frontend, and automatically reconnects after an XWayland restart.
- KakaoTalk uses a patched `xwayland-satellite` (`home/xwayland-satellite.nix`) so its
  custom-framed profile, chat and settings dialogs stay open as normal windows; menus and
  tooltips remain popups. Focusing or moving KakaoTalk also keeps the XRandR primary output
  stable, including fallback focus on the invisible tray container after closing a chat:
  changing it makes KakaoTalk unmap its main window. The user launcher (`home/kakaotalk-launcher.nix`) restores the
  existing window instead of toggling its visibility or killing its Wine prefix on every launch.
  Untitled toast windows use the measured 387×161 size at the bottom-right without taking focus;
  this prevents their 1×1 animation hints from trapping the notification body at 1×1.
- X11 tray icons (KakaoTalk under Wine) reach Noctalia through KDE's `xembedsniproxy`, built on
  its own and run as a user service (`home/xembedsniproxy`).
- Noctalia's Wi-Fi list is patched (`patches/noctalia-ap-list.patch`, wired in `home/noctalia-ap-list.nix`): every
  access point is a row with its band and channel, in one section per Wi-Fi adapter, so a network served
  by several APs (2.4/5 GHz, mesh) is no longer merged into one and each adapter can join its own network. This builds Noctalia from source; drop the module to use the cache again.
- Roblox runs through Sober, the Linux client from Flathub: `services.flatpak` plus a boot-time job
  (`flatpak-sober`, `modules/apps.nix`) that installs and updates it. Start it from the menu ("Sober")
  or `flatpak run org.vinegarhq.Sober`. The first start downloads Roblox itself.
- The monitor is set to 3440x1440@100 in `home/niri.nix`; its default 50 Hz mode makes the
  pointer and windows trail visibly. `ntsync` is loaded for Wine's thread synchronisation.

Only WPILib VMX 2020 is installed; the 2026 and 2027 IDEs and desktop tool suites are removed.

WPILib VMX 2020 runs natively: WPILibInstaller-Avalonia installs the tree into `~/wpilib/2020_vmx`, and
the `wpilib2020-vmx` package of the `nix-frc2020-vmx` input from the `nix-frc2020-vmx` subdirectory of `wsuser1101/VMX-WPILib-2020-Archive` (`home/wpilib-vmx.nix`) starts it in an FHS environment
(`wpilibcode2020_vmx`, `wpilib-elastic`, `wpilib-shell`; menu entries "WPILib VS Code 2020_vmx" and
"WPILib Elastic NT3 2020_vmx"). The old Ubuntu distrobox container (`scripts/nixos-distrobox.sh` in the
installer repo) is no longer needed; podman and distrobox stay installed.

## Flake updates when rebuilding

Run `./scripts/rebuild.sh build` to build or `./scripts/rebuild.sh switch` to apply. The script
updates `flake.lock` first and stops if the network or updated flake evaluation fails. There is
no scheduled or boot-time flake update.

## Keyboard and mouse sharing with Windows

Lan Mouse uses the pinned Niri/uinput patch from upstream PR #547 and an additional
compatibility patch that suppresses the new Hello event: Windows v0.11.0
closes connections on unknown event IDs. The user daemon starts
with the graphical session; open Lan Mouse from the launcher to configure peers. Its config
remains writable so the GUI can save addresses and certificate authorizations. UDP 4242 is
allowed by the NixOS firewall. Existing input-group and uinput permissions cover this backend.

On Windows, install with `winget install --id feschber.LanMouse --exact`, open Lan Mouse and
allow it through the Windows firewall on your private network. Add the other machine's LAN
address and screen position, approve its certificate fingerprint, then enable the connection.
The initial configuration places Windows (`192.168.0.235`) to the right of this NixOS machine.
For this experimental build, keyboard/mouse sharing must be tested in both directions;
clipboard synchronization is not included.
