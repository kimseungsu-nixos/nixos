{ lib, pkgs, ... }:

{
  # Niri is the Wayland compositor and scrollable tiling window manager.
  services.xserver.enable = true;
  # Removable-volume discovery and user-session mounting through UDisks/GVFS.
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.displayManager.sddm.enable = true;
  programs.niri.enable = true;

  # Log in automatically at boot (no SDDM password prompt).
  services.displayManager.autoLogin = {
    enable = true;
    user = "linux";
  };
  services.displayManager.defaultSession = "niri";

  # SDDM autologin cannot unlock GNOME Keyring with the user's login password.
  # Keep existing keyring files, but disable the daemon to prevent its boot prompt.
  services.gnome.gnome-keyring.enable = false;

  services.xserver.xkb = {
    layout = "kr";
    variant = "kr104";
    options = "korean:ralt_hangul,korean:rctrl_hanja";
  };

  services.printing.enable = true;

  # Bluetooth and firmware for the Intel wireless controller. Noctalia supplies the UI.
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General.FastConnectable = true;
      # Re-establish a dropped link to a paired device a few times.
      Policy = {
        AutoEnable = true;
        ReconnectAttempts = 7;
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
    };
  };
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # BlueZ does not dial out to paired devices by itself after boot (it waits for the device to
  # connect). Connect every paired device once Bluetooth is up; ones that are off just time out.
  systemd.services.bluetooth-autoconnect = {
    description = "Connect paired Bluetooth devices at boot";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.bluez pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      sleep 5
      bluetoothctl power on
      for dev in $(bluetoothctl devices Paired | cut -d' ' -f2); do
        bluetoothctl trust "$dev"
        timeout 25 bluetoothctl connect "$dev" &
      done
      wait
    '';
  };

  # Kime is Korean-first and provides both Wayland and XIM frontends; XIM is
  # the path Proton/Wine applications use under XWayland.
  i18n.inputMethod = {
    enable = true;
    type = lib.mkForce "kime";
    # home/kime.nix supervises XIM separately so it reconnects after XWayland exits.
    kime.daemonModules = [ "Wayland" "Indicator" ];
    kime.iconColor = "White";
    kime.extraConfig = ''
      engine:
        default_category: Hangul
    '';
  };

  # Prefer native Wayland for Chromium/Electron applications when supported.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
