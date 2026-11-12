{ config, lib, pkgs, ... }:

let
  devices = [ "noctalia-ap" "noctalia-ap5" ];
  bridge = "noctalia-lan";
  gateway = "172.30.0.1";
  cidr = "172.30.0.0/24";
  unit = "noctalia-hotspot.service";
  runtimeDir = "noctalia-hotspot";
  networkmanager = config.networking.networkmanager.package;
  mdnsRevision = "488feaf7da1a4b54de120ea00f0f3eb629cdfd8e";
  mdnsRepeater = pkgs.stdenv.mkDerivation {
    pname = "mdns-repeater";
    version = "unstable";
    src = pkgs.fetchFromGitHub {
      owner = "geekman";
      repo = "mdns-repeater";
      rev = mdnsRevision;
      hash = "sha256-J+d7povsE/nXJtfP4fQMMl3obAUwYmp5Shn5eV+onsE=";
    };
    makeFlags = [ "HGVERSION=${mdnsRevision}" ];
    installPhase = ''
      runHook preInstall
      install -Dm755 mdns-repeater "$out/bin/mdns-repeater"
      runHook postInstall
    '';
  };

  service = pkgs.writeShellApplication {
    name = "noctalia-hotspot-service";
    runtimeInputs = [
      networkmanager pkgs.iw pkgs.iproute2 pkgs.hostapd pkgs.dnsmasq
      pkgs.coreutils pkgs.diffutils pkgs.gawk pkgs.systemd pkgs.util-linux
      pkgs.jq pkgs.nftables pkgs.iptables mdnsRepeater
    ];
    text = ''
      settings=${lib.escapeShellArg "${config.home-manager.users.linux.xdg.configHome}/noctalia/hotspot.conf"}
      unit=${lib.escapeShellArg unit}
      ap_devices=( ${lib.escapeShellArgs devices} )
      bridge=${lib.escapeShellArg bridge}
      gateway=${lib.escapeShellArg gateway}
      cidr=${lib.escapeShellArg cidr}
      ${builtins.readFile ../scripts/noctalia-hotspot-network.sh}
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
  services.udev.extraRules = lib.mkAfter (
    lib.concatMapStrings (device: ''
      ACTION=="add|remove", SUBSYSTEM=="net", KERNEL=="${device}", ENV{NM_UNMANAGED}="1", RUN="${pkgs.coreutils}/bin/true"
    '') devices + ''
      ACTION=="add", SUBSYSTEM=="net", KERNEL=="${bridge}", ENV{NM_UNMANAGED}="1"
    ''
  );
  networking.nat = {
    enable = true;
    internalInterfaces = [ bridge ];
  };
  networking.firewall.interfaces.${bridge} = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 5353 ];
  };
  # Replies can arrive on a selected uplink that is not the desktop's default route.
  networking.firewall.extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
    if iptables -w -t mangle -S nixos-fw-rpfilter >/dev/null 2>&1; then
      iptables -w -t mangle -I nixos-fw-rpfilter 1 -m conntrack --ctstate ESTABLISHED,RELATED \
        --ctdir REPLY --ctorigsrc ${cidr} -j RETURN
    fi
    ${service}/bin/noctalia-hotspot-service mdns-firewall
  '';
  networking.firewall.extraReversePathFilterRules = lib.mkIf config.networking.nftables.enable ''
    ct state established,related ct direction reply ct original ip saddr ${cidr} accept
  '';

  services.avahi = {
    enable = true;
    allowInterfaces = [ bridge ];
    ipv6 = false;
    openFirewall = false;
    publish = {
      enable = true;
      addresses = true;
    };
  };
  # Enabling the hotspot responder should not turn on CUPS printer discovery.
  services.printing.browsed.enable = lib.mkDefault false;
}
