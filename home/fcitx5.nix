{ osConfig, ... }:

{
  xdg.configFile."fcitx5/profile".text = ''
    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=hangul

    [Groups/0/Items/0]
    Name=keyboard-us
    Layout=

    [Groups/0/Items/1]
    Name=hangul
    Layout=us

    [GroupOrder]
    0=Default
  '';

  xdg.configFile."fcitx5/config".text = ''
    [Hotkey/TriggerKeys]
    0=Hangul
    1=Shift+space

    [Behavior]
    ActiveByDefault=True
  '';

  # Run the addon wrapper, so the Hangul engine and GTK/Qt modules are found.
  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx 5 input method";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${osConfig.i18n.inputMethod.package}/bin/fcitx5";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # The service above owns startup instead of the package's XDG autostart entry.
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Hidden=true
  '';
}
