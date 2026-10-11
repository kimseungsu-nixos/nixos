# My-NixOS

NixOS flake for the `linux` machine: niri (scrollable-tiling Wayland compositor) with the
Noctalia shell.

```bash
sudo nixos-rebuild switch --flake .#linux
```

## Layout

| Path | What |
| --- | --- |
| `flake.nix` | inputs (nixpkgs 26.05, home-manager, noctalia, hnc2020, nix-packages, ...) and the host |
| `configuration.nix` | imports the modules below |
| `modules/system.nix` | boot, network, locale, user, ssh, automatic Nix cleanup |
| `modules/desktop.nix` | niri session, keyboard, Korean input (kime), audio, Bluetooth, printing |
| `modules/apps.nix` | Hancom Office, Thunar, podman/distrobox, CLI tools |
| `modules/theme.nix` | Catppuccin Mocha: login screen, cursor, fonts |
| `home.nix`, `home/` | home-manager: niri config (`niri.nix`), GTK theme and foot (`home.nix`), GUI apps (`packages.nix`), tray bridge (`xembedsniproxy/`), clipboard helper (`copy-image/`) |
| `hardware-configuration.nix` | generated for this machine |

## Notes

- `hnc2020` (Hancom Office) is a private repo fetched over HTTPS with the git
  credentials from `gh auth login`. Update with `nix flake update hnc2020`, and
  rebuild with `--sudo` so the fetch runs as your user, not root.
- Old builds are cleaned up automatically: a weekly `nix.gc` deletes
  generations older than 7 days and `/boot` keeps the last 5.
- Screenshots (`Print`, `Mod+Shift+S`) go to `~/Pictures/Screenshots` and onto the clipboard as
  PNG and BMP plus the file itself (`home/copy-image`), so they paste into Wine programs and
  file managers too.
- X11 tray icons (KakaoTalk under Wine) reach Noctalia through KDE's `xembedsniproxy`, built on
  its own and run as a user service (`home/xembedsniproxy`).
- Noctalia's Wi-Fi list is patched (`patches/noctalia-ap-list.patch`, wired in `home/noctalia-ap-list.nix`): every
  access point is a row with its band and channel, in one section per Wi-Fi adapter, so a network served
  by several APs (2.4/5 GHz, mesh) is no longer merged into one and each adapter can join its own network. This builds Noctalia from source; drop the module to use the cache again.
- The monitor is set to 3440x1440@100 in `home/niri.nix`; its default 50 Hz mode makes the
  pointer and windows trail visibly. `ntsync` is loaded for Wine's thread synchronisation.

WPILib 2027 alpha comes from the `wpi2027-nix` input (`home/wpilib-2027.nix`): SysId, Glass, OutlineViewer,
DataLogTool, WPICal, WPILib Utility (built from the allwpilib sources), AdvantageScope, Choreo, PathPlanner,
the Elastic dashboard, and "WPILib VS Code 2027" (`wpilibcode2027`: VS Code with the WPILib, C++, Java and Gradle
extensions and JDK 25, with its own settings).

WPILib VMX 2020 runs natively: WPILibInstaller-Avalonia installs the tree into `~/wpilib/2020_vmx`, and
the `wpilib2020-vmx` package of the `nix-frc2020-vmx` input (`home/wpilib-vmx.nix`) starts it in an FHS environment
(`wpilibcode2020_vmx`, `wpilib-elastic`, `wpilib-shell`; menu entries "WPILib VS Code 2020_vmx" and
"WPILib Elastic NT3 2020_vmx"). The old Ubuntu distrobox container (`scripts/nixos-distrobox.sh` in the
installer repo) is no longer needed; podman and distrobox stay installed.
