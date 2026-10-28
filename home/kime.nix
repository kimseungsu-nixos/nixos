{ pkgs, ... }:

{
  # XIM must outlive an individual XWayland server. Kime's main daemon does
  # not restart the XIM child after the X11 connection closes, so supervise it
  # separately and leave the Wayland frontend/indicator with the main daemon.
  xdg.configFile."kime/config.yaml".text = ''
    daemon:
      modules: [Wayland,Indicator]
    indicator:
      icon_color: White
    engine:
      default_category: Hangul
  '';

  systemd.user.services.kime-xim = {
    Unit = {
      Description = "Kime XIM bridge for XWayland applications";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = "${pkgs.kime}/bin/kime-xim --log warn";
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
