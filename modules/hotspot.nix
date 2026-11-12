{ config, lib, pkgs, ... }:

let
  device = "noctalia-ap";
  unit = "noctalia-hotspot.service";
  ssid = "NixOS Hotspot";
  subnet = "10.42.73";
  runtimeDir = "noctalia-hotspot";
  networkmanager = config.networking.networkmanager.package;

  service = pkgs.writeShellApplication {
    name = "noctalia-hotspot-service";
    runtimeInputs = [ networkmanager pkgs.iw pkgs.iproute2 pkgs.hostapd pkgs.dnsmasq pkgs.coreutils pkgs.gawk pkgs.systemd ];
    text = ''
      export LC_ALL=C

      if [[ $1 == stop ]]; then
        if [[ -e $RUNTIME_DIRECTORY/interface ]] && iw dev ${device} info >/dev/null 2>&1; then
          iw dev ${device} del
        fi
        exit 0
      fi

      fail() {
        systemd-notify --status="$1"
        printf '%s\n' "$1" >&2
        exit 1
      }

      frequency() {
        iw dev "$1" link | awk '$1 == "freq:" && !found++ { print int($2) }'
      }

      select_adapter() {
        local wifi iface type state phy
        local -A connected_phys=()
        wifi=$(nmcli -t -f DEVICE,TYPE,STATE device status) || return 1
        while IFS=: read -r iface type state; do
          if [[ $type == wifi && $state == connected* && -e /sys/class/net/$iface/phy80211 ]]; then
            connected_phys[$(readlink -f "/sys/class/net/$iface/phy80211")]=1
          fi
        done <<< "$wifi"

        # Prefer an idle radio independent of the connected Wi-Fi interfaces.
        uplink=
        while IFS=: read -r iface type state; do
          [[ $type == wifi && $iface != ${device} && -e /sys/class/net/$iface/phy80211 ]] || continue
          [[ $(nmcli -g WIFI-PROPERTIES.AP device show "$iface") == yes ]] || continue
          phy=$(readlink -f "/sys/class/net/$iface/phy80211")
          if [[ $state == disconnected && ! ''${connected_phys[$phy]+yes} ]]; then
            adapter=$iface
            uplink=
            freq=2437
            return 0
          fi
          if [[ $state == connected* && -z $uplink ]]; then
            freq=$(frequency "$iface") || continue
            if [[ -n $freq ]]; then
              uplink=$iface
            fi
          fi
        done <<< "$wifi"
        [[ -n $uplink ]] || return 1
        adapter=$uplink
      }

      attempt=0
      until select_adapter; do
        ((++attempt < 20)) || fail '핫스팟을 지원하는 Wi‑Fi 어댑터를 사용할 수 없습니다.'
        sleep 0.5
      done

      phy=$(basename "$(readlink -f "/sys/class/net/$adapter/phy80211")")
      channel=$(iw phy "$phy" info | awk -v freq="$freq" '
        $1 == "*" && $2 ~ /^[0-9]+([.][0-9]+)?$/ && int($2) == freq && $3 == "MHz" &&
        !/disabled|no IR|radar detection/ && !found++ { gsub(/[][]/, "", $4); print $4 }
      ')
      case "$freq" in
        24[0-9][0-9]) band=g ;;
        5[0-8][0-9][0-9]) band=a ;;
        *) channel= ;;
      esac
      [[ -n $channel ]] || fail '이 채널에서는 핫스팟을 시작할 수 없습니다. 2.4GHz 또는 DFS가 아닌 5GHz Wi‑Fi에 연결한 뒤 다시 시도하세요.'

      # hostapd owns the virtual AP while NetworkManager manages the station interface.
      [[ ! -e /sys/class/net/${device} ]] || fail '핫스팟 인터페이스가 이미 사용 중입니다.'
      read -r -a bytes <<< "$(od -An -N5 -tx1 /dev/urandom)"
      printf -v mac '02:%s:%s:%s:%s:%s' "''${bytes[@]}"
      iw dev "$adapter" interface add ${device} type __ap addr "$mac" || fail '이 어댑터에서 가상 핫스팟 인터페이스를 만들 수 없습니다.'
      touch "$RUNTIME_DIRECTORY/interface"

      if [[ ! -s $STATE_DIRECTORY/password ]]; then
        od -An -N12 -tx1 /dev/urandom | tr -d '[:space:]' > "$STATE_DIRECTORY/password.new"
        mv "$STATE_DIRECTORY/password.new" "$STATE_DIRECTORY/password"
      fi
      cat > "$RUNTIME_DIRECTORY/hostapd.conf" <<EOF
      interface=${device}
      driver=nl80211
      ctrl_interface=$RUNTIME_DIRECTORY/hostapd
      ssid=${ssid}
      hw_mode=$band
      channel=$channel
      wpa=2
      wpa_key_mgmt=WPA-PSK
      rsn_pairwise=CCMP
      wpa_passphrase=$(cat "$STATE_DIRECTORY/password")
      EOF

      if [[ -n $uplink && $(frequency "$uplink") != "$freq" ]]; then
        fail 'Wi‑Fi 채널이 바뀌었습니다. 다시 연결된 뒤 핫스팟을 켜세요.'
      fi

      hostapd "$RUNTIME_DIRECTORY/hostapd.conf" &
      ap_pid=$!
      attempt=0
      until [[ $(hostapd_cli -p "$RUNTIME_DIRECTORY/hostapd" -i ${device} status 2>/dev/null) == state=ENABLED$'\n'* ]]; do
        if ! kill -0 "$ap_pid" 2>/dev/null || ((++attempt >= 50)); then
          fail '이 채널에서 핫스팟을 시작하지 못했습니다. 다른 Wi‑Fi 채널에서 다시 시도하세요.'
        fi
        sleep 0.1
      done

      ip address add ${subnet}.1/24 dev ${device}
      dnsmasq --keep-in-foreground --conf-file=/dev/null --bind-interfaces \
        --interface=${device} --except-interface=lo --listen-address=${subnet}.1 \
        --dhcp-range=${subnet}.10,${subnet}.200,12h --leasefile-ro &
      dhcp_pid=$!
      sleep 0.2
      kill -0 "$dhcp_pid" 2>/dev/null || fail '핫스팟의 DHCP와 DNS를 시작하지 못했습니다.'
      install -m 0640 -g networkmanager "$STATE_DIRECTORY/password" "$RUNTIME_DIRECTORY/password"
      systemd-notify --ready

      # Release a shared radio as soon as its uplink leaves this channel so it can reconnect.
      while kill -0 "$ap_pid" 2>/dev/null && kill -0 "$dhcp_pid" 2>/dev/null; do
        if [[ -n $uplink && $(frequency "$uplink") != "$freq" ]]; then
          exit 0
        fi
        sleep 1
      done
      fail '핫스팟 서비스가 중단되었습니다.'
    '';
  };

  button = pkgs.writeShellApplication {
    name = "noctalia-hotspot";
    runtimeInputs = [ pkgs.systemd pkgs.zenity pkgs.util-linux pkgs.libnotify ];
    text = ''
      show_credentials() {
        local password
        if ! password=$(< /run/${runtimeDir}/password) || [[ -z $password ]]; then
          zenity --error --title='Wi‑Fi 핫스팟' --text='핫스팟 암호를 읽을 수 없습니다.'
          return
        fi
        printf '네트워크 이름\n%s\n\n암호\n%s\n' '${ssid}' "$password" |
          zenity --text-info --title='Wi‑Fi 핫스팟 켜짐' --width=350 --height=240
      }

      if [[ ''${1:-} == details ]]; then
        if systemctl is-active --quiet ${unit}; then
          show_credentials
        else
          notify-send 'Wi‑Fi 핫스팟' '핫스팟이 꺼져 있습니다.'
        fi
        exit 0
      fi

      exec 9>"$XDG_RUNTIME_DIR/noctalia-hotspot.lock"
      flock -n 9 || exit 0
      if systemctl is-active --quiet ${unit}; then
        if systemctl stop ${unit}; then
          notify-send 'Wi‑Fi 핫스팟' '핫스팟을 껐습니다.'
        else
          notify-send 'Wi‑Fi 핫스팟' '핫스팟을 끄지 못했습니다.'
        fi
      elif systemctl start ${unit}; then
        flock -u 9
        show_credentials
      else
        reason=$(systemctl show -p StatusText --value ${unit})
        notify-send 'Wi‑Fi 핫스팟' "''${reason:-핫스팟을 시작하지 못했습니다.}"
      fi
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
          (action.lookup("verb") === "start" || action.lookup("verb") === "stop") &&
          subject.user === "linux" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  networking.networkmanager.unmanaged = [ "interface-name:${device}" ];
  # NixOS queues a supplicant restart on WLAN add/remove. Clear it for the hostapd interface.
  services.udev.extraRules = lib.mkAfter ''
    ACTION=="add|remove", SUBSYSTEM=="net", KERNEL=="${device}", RUN="${pkgs.coreutils}/bin/true"
  '';
  networking.nat = {
    enable = true;
    internalInterfaces = [ device ];
  };
  networking.firewall.interfaces.${device} = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 67 ];
  };

  home-manager.users.linux.programs.noctalia.settings.widget.hotspot = {
    type = "custom_button";
    glyph = "access-point";
    tooltip = "Wi‑Fi 핫스팟 · 클릭하여 켜기/끄기 · 우클릭하여 암호 보기";
    actions = {
      left = "exec ${button}/bin/noctalia-hotspot";
      right = "exec ${button}/bin/noctalia-hotspot details";
    };
  };
}
