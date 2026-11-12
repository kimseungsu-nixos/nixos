export LC_ALL=C

ssid='NixOS Hotspot'
password=
mode=auto
channel24=0
channel5=0
uplink=auto

read_preferences() {
  local -a values=()
  mapfile -t values
  if (( ${#values[@]} < 5 || ${#values[@]} > 6 )); then
    return 1
  fi
  mode=${values[0]}
  channel24=${values[1]}
  channel5=${values[2]}
  ssid=${values[3]}
  password=${values[4]}
  uplink=${values[5]:-auto}

  [[ $mode == auto || $mode == 2.4 || $mode == 5 || $mode == dual ]] &&
    [[ $channel24 =~ ^([0-9]|1[0-3])$ && $channel5 =~ ^(0|[1-9][0-9]{0,2})$ ]] &&
    (( channel5 <= 196 && ${#ssid} >= 1 && ${#ssid} <= 32 )) &&
    [[ $ssid != *[[:cntrl:]]* ]] &&
    { [[ $uplink == auto ]] || valid_uplink "$uplink"; } &&
    { [[ -z $password ]] ||
      { (( ${#password} >= 8 && ${#password} <= 63 )) && [[ $password != *[![:print:]]* ]]; }; }
}

fail() {
  if [[ $EUID == 0 && -n ${NOTIFY_SOCKET:-} ]]; then
    systemd-notify --status="$1"
  fi
  printf '%s\n' "$1" >&2
  exit 1
}

frequency() {
  iw dev "$1" link | awk '$1 == "freq:" && !found++ { print int($2) }'
}

available_radios() {
  local wifi iface type state phy freq preference
  local -A connected=() emitted=()
  wifi=$(nmcli -t -f DEVICE,TYPE,STATE device status) || return 1
  while IFS=: read -r iface type state; do
    if [[ $type == wifi && $state == connected* && -e /sys/class/net/$iface/phy80211 ]]; then
      phy=$(basename "$(readlink -f "/sys/class/net/$iface/phy80211")")
      connected[$phy]=1
    fi
  done <<< "$wifi"

  # An independent radio can use any permitted channel, so prefer it to a shared radio.
  for preference in disconnected connected; do
    while IFS=: read -r iface type state; do
      [[ $type == wifi && $state == "$preference"* && -e /sys/class/net/$iface/phy80211 ]] || continue
      [[ $(nmcli -g WIFI-PROPERTIES.AP device show "$iface") == yes ]] || continue
      phy=$(basename "$(readlink -f "/sys/class/net/$iface/phy80211")")
      [[ ! ${emitted[$phy]+yes} ]] || continue
      if [[ $preference == connected ]]; then
        freq=$(frequency "$iface") || continue
        [[ -n $freq ]] || continue
      else
        [[ ! ${connected[$phy]+yes} ]] || continue
        freq=0
      fi
      emitted[$phy]=1
      printf '%s %s %s\n' "$iface" "$phy" "$freq"
    done <<< "$wifi"
  done
}

candidate_channels() {
  local wanted_band=$1 wanted_channel=$2 radio iface phy linked channel
  for radio in "${radios[@]}"; do
    read -r iface phy linked <<< "$radio"
    channel=$(iw phy "$phy" info | awk -v linked="$linked" -v wanted="$wanted_band" -v requested="$wanted_channel" '
      $1 == "*" && $2 ~ /^[0-9]+([.][0-9]+)?$/ && $3 == "MHz" && !/disabled|no IR|radar detection/ {
        freq = int($2)
        band = freq >= 2400 && freq < 2500 ? "2.4" : (freq >= 5000 && freq < 5900 ? "5" : "")
        gsub(/[][]/, "", $4)
        channel = int($4)
        if (band == "" || (wanted != "auto" && band != wanted) ||
            (linked && freq != linked) || (requested && channel != requested)) next
        rank = band == "2.4" ? (channel == 6 ? 0 : 1) : (channel == 36 ? 2 : 3)
        if (!found || rank < best) {
          found = 1
          best = rank
          result = band " " channel
        }
      }
      END { if (found) print result }
    ') || continue
    if [[ -n $channel ]]; then
      printf '%s %s\n' "$radio" "$channel"
    fi
  done
}

build_plan() {
  local low high low_phy high_phy
  local -a candidates=() low_band=() high_band=()
  plan=()
  case "$mode" in
    auto) mapfile -t candidates < <(candidate_channels auto 0) ;;
    2.4) mapfile -t candidates < <(candidate_channels 2.4 "$channel24") ;;
    5) mapfile -t candidates < <(candidate_channels 5 "$channel5") ;;
    dual)
      mapfile -t low_band < <(candidate_channels 2.4 "$channel24")
      mapfile -t high_band < <(candidate_channels 5 "$channel5")
      for low in "${low_band[@]}"; do
        read -r _ low_phy _ <<< "$low"
        for high in "${high_band[@]}"; do
          read -r _ high_phy _ <<< "$high"
          if [[ $low_phy != "$high_phy" ]]; then
            plan=("$low" "$high")
            return 0
          fi
        done
      done
      return 1
      ;;
  esac
  (( ${#candidates[@]} )) || return 1
  plan=("${candidates[0]}")
}

plan_error() {
  if (( ! ${#radios[@]} )); then
    printf '%s' '핫스팟을 지원하는 Wi‑Fi 어댑터를 사용할 수 없습니다.'
  elif [[ $mode == dual ]] && (( ${#radios[@]} < 2 )); then
    printf '%s' '2.4GHz와 5GHz 동시 송출에는 AP 모드를 지원하는 Wi‑Fi 어댑터가 두 개 필요합니다.'
  else
    printf '%s' '선택한 대역과 채널을 사용할 수 없습니다. 연결 중인 Wi‑Fi와 같은 채널이나 자동 채널을 선택하세요.'
  fi
}

save_preferences() {
  [[ $EUID != 0 ]] || fail '데스크톱 세션에서 설정을 변경하세요.'
  read_preferences < <(head -c 512) ||
    fail '이름은 1~32바이트, 비밀번호는 인쇄 가능한 ASCII 8~63자로 입력하세요.'
  mapfile -t radios < <(available_radios)
  build_plan || fail "$(plan_error)"
  if [[ $uplink != auto && -z $(selected_routes) ]]; then
    fail '선택한 공유 네트워크에 연결한 뒤 다시 적용하세요.'
  fi

  local directory candidate previous reason
  directory=$(dirname "$settings")
  mkdir -p "$directory"
  exec 9>"$XDG_RUNTIME_DIR/noctalia-hotspot-settings.lock"
  flock -n 9 || fail '다른 핫스팟 설정을 적용 중입니다.'
  candidate=$(mktemp "$directory/.hotspot.XXXXXX")
  previous=
  trap 'if [[ -n $candidate ]]; then unlink "$candidate"; fi; if [[ -n $previous ]]; then unlink "$previous"; fi' RETURN
  printf '%s\n' "$mode" "$channel24" "$channel5" "$ssid" "$password" "$uplink" > "$candidate"
  if cmp -s "$candidate" "$settings" ||
     { [[ $uplink == auto ]] && cmp -s <(head -n 5 "$candidate") "$settings"; } ||
     [[ ! -e $settings && $mode == auto && $channel24 == 0 && $channel5 == 0 &&
        $ssid == 'NixOS Hotspot' && -z $password && $uplink == auto ]]; then
    return
  fi
  if [[ -f $settings ]]; then
    previous=$(mktemp "$directory/.hotspot-previous.XXXXXX")
    cp -- "$settings" "$previous"
  fi
  mv -f -- "$candidate" "$settings"
  candidate=
  if systemctl is-active --quiet "$unit" && ! systemctl --no-ask-password restart "$unit"; then
    reason=$(systemctl show -p StatusText --value "$unit")
    if [[ -n $previous ]]; then
      mv -f -- "$previous" "$settings"
      previous=
    else
      unlink "$settings"
    fi
    systemctl --no-ask-password start "$unit" || true
    fail "${reason:-핫스팟에 새 설정을 적용하지 못했습니다.}"
  fi
}

links_unchanged() {
  local entry iface linked
  for entry in "${plan[@]}"; do
    read -r iface _ linked _ <<< "$entry"
    if [[ $linked != 0 && $(frequency "$iface") != "$linked" ]]; then
      return 1
    fi
  done
}

aps_ready() {
  local device
  for device in "${active_devices[@]}"; do
    if [[ $(hostapd_cli -p "$RUNTIME_DIRECTORY/hostapd" -i "$device" status 2>/dev/null) != state=ENABLED$'\n'* ]]; then
      return 1
    fi
  done
}

case "$1" in
  uplinks) list_uplinks; exit 0 ;;
  mdns-firewall) mdns_firewall add; exit 0 ;;
  save) save_preferences; exit 0 ;;
  stop)
    mdns_firewall remove
    stop_uplink_routing
    for device in "${ap_devices[@]}"; do
      if [[ -e $RUNTIME_DIRECTORY/interface.$device ||
            ( $device == "${ap_devices[0]}" && -e $RUNTIME_DIRECTORY/interface ) ]] &&
         iw dev "$device" info >/dev/null 2>&1; then
        iw dev "$device" del
      fi
    done
    if [[ -e $RUNTIME_DIRECTORY/bridge && -e /sys/class/net/$bridge ]]; then
      ip link del dev "$bridge"
    fi
    exit 0
    ;;
  start) [[ $EUID == 0 ]] || fail '시스템 서비스로 핫스팟을 시작하세요.' ;;
  *) exit 2 ;;
esac

if [[ -e $settings ]]; then
  # Read the user-owned file with the desktop user's permissions.
  read_preferences < <(setpriv --reuid linux --regid users --init-groups timeout 2s head -c 512 -- "$settings") ||
    fail '저장한 핫스팟 설정을 읽을 수 없습니다.'
fi

attempt=0
while true; do
  mapfile -t radios < <(available_radios)
  if build_plan; then
    break
  fi
  if (( ${#radios[@]} || ++attempt >= 20 )); then
    fail "$(plan_error)"
  fi
  sleep 0.5
done

if [[ -z $password ]]; then
  if [[ ! -s $STATE_DIRECTORY/password ]]; then
    od -An -N12 -tx1 /dev/urandom | tr -d '[:space:]' > "$STATE_DIRECTORY/password.new"
    mv "$STATE_DIRECTORY/password.new" "$STATE_DIRECTORY/password"
  fi
  password=$(< "$STATE_DIRECTORY/password")
fi
ssid_hex=$(printf '%s' "$ssid" | od -An -v -tx1 | tr -d '[:space:]')

create_hotspot_bridge
route_snapshot=
if [[ $uplink != auto ]]; then
  start_uplink_routing
fi

active_devices=()
configs=()
status=
for index in "${!plan[@]}"; do
  read -r iface _ _ band channel <<< "${plan[$index]}"
  device=${ap_devices[$index]}
  if [[ $band == 2.4 ]]; then
    hw_mode=g
  else
    hw_mode=a
  fi

  [[ ! -e /sys/class/net/$device ]] || fail '핫스팟 인터페이스가 이미 사용 중입니다.'
  read -r -a bytes <<< "$(od -An -N5 -tx1 /dev/urandom)"
  printf -v mac '02:%s:%s:%s:%s:%s' "${bytes[@]}"
  iw dev "$iface" interface add "$device" type __ap addr "$mac" ||
    fail '이 어댑터에서 가상 핫스팟 인터페이스를 만들 수 없습니다.'
  touch "$RUNTIME_DIRECTORY/interface.$device"
  config="$RUNTIME_DIRECTORY/hostapd-$device.conf"
  cat > "$config" <<CONF
interface=$device
driver=nl80211
bridge=$bridge
ctrl_interface=$RUNTIME_DIRECTORY/hostapd
ssid2=$ssid_hex
hw_mode=$hw_mode
channel=$channel
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=$password
CONF
  active_devices+=("$device")
  configs+=("$config")
  status+="${status:+  ·  }$band GHz / $channel"
done

links_unchanged || fail 'Wi‑Fi 채널이 바뀌었습니다. 다시 연결된 뒤 핫스팟을 켜세요.'
hostapd "${configs[@]}" &
ap_pid=$!
attempt=0
until aps_ready; do
  if ! kill -0 "$ap_pid" 2>/dev/null || ((++attempt >= 50)); then
    fail '선택한 채널에서 핫스팟을 시작하지 못했습니다.'
  fi
  sleep 0.1
done

dns_args=()
if [[ $uplink != auto ]]; then
  # Clients send DNS directly through the selected routing policy.
  dns_args+=(--port=0 "--dhcp-option=option:dns-server$(selected_dns)")
fi
subnet=${gateway%.*}
dnsmasq --keep-in-foreground --conf-file=/dev/null --bind-interfaces --except-interface=lo --leasefile-ro \
  --interface="$bridge" --listen-address="$gateway" --dhcp-range="$subnet.10,$subnet.200,12h" "${dns_args[@]}" &
dhcp_pid=$!
sleep 0.2
kill -0 "$dhcp_pid" 2>/dev/null || fail '핫스팟의 DHCP와 DNS를 시작하지 못했습니다.'
mdns_current=
mdns_pid=
refresh_mdns
status+="  ·  $gateway"
if [[ $uplink != auto ]]; then
  status+="  ·  $uplink"
fi
printf '%s\n' "$ssid" "$status" > "$RUNTIME_DIRECTORY/status"
printf '%s\n' "$password" > "$RUNTIME_DIRECTORY/password"
chmod 0640 "$RUNTIME_DIRECTORY/status" "$RUNTIME_DIRECTORY/password"
systemd-notify --ready

# Release the shared radio before it attempts to associate on a different channel.
ticks=0
while kill -0 "$ap_pid" 2>/dev/null && kill -0 "$dhcp_pid" 2>/dev/null; do
  links_unchanged || exit 0
  if [[ $uplink != auto ]]; then
    refresh_uplink_routes
  fi
  if (( ++ticks % 3 == 0 )); then
    refresh_mdns
  fi
  sleep 1
done
fail '핫스팟 서비스가 중단되었습니다.'
