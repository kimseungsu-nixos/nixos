{ config, lib, pkgs, ... }:

let
  devices = [ "noctalia-ap" "noctalia-ap5" ];
  unit = "noctalia-hotspot.service";
  runtimeDir = "noctalia-hotspot";
  networkmanager = config.networking.networkmanager.package;

  service = pkgs.writeShellApplication {
    name = "noctalia-hotspot-service";
    runtimeInputs = [
      networkmanager pkgs.iw pkgs.iproute2 pkgs.hostapd pkgs.dnsmasq
      pkgs.coreutils pkgs.diffutils pkgs.gawk pkgs.systemd pkgs.util-linux
    ];
    text = ''
      settings=${lib.escapeShellArg "${config.home-manager.users.linux.xdg.configHome}/noctalia/hotspot.conf"}
      unit=${lib.escapeShellArg unit}
      ap_devices=( ${lib.escapeShellArgs devices} )
      ${builtins.readFile ../scripts/noctalia-hotspot.sh}
    '';
  };
in
{
  systemd.services.noctalia-hotspot = {
    description = "Noctalia Wi-Fi hotspot";
    bindsTo = [ "NetworkManager.service" ];
    after = [ "NetworkManager.service" "firewall.service" ];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${service}/bin/noctalia-hotspot-service start";
      ExecStopPost = "${service}/bin/noctalia-hotspot-service stop";
      Group = "networkmanager";
      RuntimeDirectory = runtimeDir;
      RuntimeDirectoryMode = "0750";
      StateDirectory = runtimeDir;
      StateDirectoryMode = "0700";
      UMask = "0077";
      TimeoutStartSec = "35s";
    };
  };

  # Let the logged-in desktop user operate just this unit via the panel.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") === "${unit}" &&
          (["start", "stop", "restart"].indexOf(action.lookup("verb")) !== -1) &&
          subject.user === "linux" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  home-manager.users.linux.home.packages = [ service ];

  networking.networkmanager.unmanaged = [ "interface-name:${builtins.head devices}" ];
  # NixOS queues a supplicant restart on WLAN add/remove. Clear it for the hostapd interfaces.
  services.udev.extraRules = lib.mkAfter (lib.concatMapStrings (device: ''
    ACTION=="add|remove", SUBSYSTEM=="net", KERNEL=="${device}", ENV{NM_UNMANAGED}="1", RUN="${pkgs.coreutils}/bin/true"
  '') devices);
  networking.nat = {
    enable = true;
    internalInterfaces = devices;
  };
  networking.firewall.interfaces = lib.genAttrs devices (_: {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 ];
  });
}
