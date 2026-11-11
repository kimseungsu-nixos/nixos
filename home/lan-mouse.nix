{ lib, pkgs, lan-mouse-niri, ... }:
let
  package = import ../packages/lan-mouse.nix {
    inherit lan-mouse-niri;
    system = pkgs.stdenv.hostPlatform.system;
  };
in {
  home.packages = [ package ];

  systemd.user.services.lan-mouse = {
    Unit = {
      Description = "Lan Mouse keyboard and pointer sharing";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${package}/bin/lan-mouse --emulation-backend uinput daemon";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Keep the file writable: the GUI stores peers and certificate authorizations here.
  home.activation.seedLanMouseConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/lan-mouse"
    if [ ! -e "$config_dir/config.toml" ]; then
      $DRY_RUN_CMD install -Dm600 ${pkgs.writeText "lan-mouse-config.toml" ''
        emulation_backend = "uinput"
        port = 4242

        [[clients]]
        position = "right"
        ips = ["192.168.0.235"]
        activate_on_startup = true
      ''} "$config_dir/config.toml"
    fi
  '';
}
