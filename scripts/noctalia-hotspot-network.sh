route_table=17300
route_priority=100
guard_priority=101
guard_table=noctalia_hotspot_uplink
runtime_path=/run/noctalia-hotspot

valid_uplink() {
  [[ $1 =~ ^[a-zA-Z0-9_.-]{1,15}$ && $1 != auto && $1 != lo && $1 != "$bridge" &&
     $1 != "${ap_devices[0]}" && $1 != "${ap_devices[1]}" ]]
}

route_json() {
  { ip -4 -j route show table all "$@" 2>/dev/null || printf '[]\n'; } |
    jq -c --arg managed_table "$route_table" '[
      .[] | select((.type // "unicast") == "unicast" and .table != "local" and
                   (.table | tostring) != $managed_table and
                   ((.flags // []) | index("linkdown") | not))
    ]'
}

list_uplinks() {
  local iface connection devices
  local -A names=()
  devices=$(nmcli -t --escape no -f DEVICE,CONNECTION device status 2>/dev/null || true)
  while IFS=: read -r iface connection; do
    if valid_uplink "$iface" && [[ -n $connection && $connection != -- ]]; then
      names[$iface]=$connection
    fi
  done <<< "$devices"

  while IFS= read -r iface; do
    if valid_uplink "$iface"; then
      printf '%s\t%s\n' "$iface" "${names[$iface]:-$iface}"
    fi
  done < <(route_json | jq -r 'map(.dev // empty) | unique[]')
}

selected_routes() {
  route_json dev "$uplink" | jq -r '
    sort_by(.dst, (.metric // 0)) | unique_by(.dst)[] |
    [.dst, (.gateway // "-"), (.metric // 0)] | @tsv
  '
}

refresh_uplink_routes() {
  local routes dst next_hop metric
  local -a path=()
  routes=$(selected_routes)
  [[ $routes != "$route_snapshot" ]] || return 0
  # The unreachable rule blocks fallback while the table is empty or changing.
  ip -4 route flush table "$route_table" 2>/dev/null || true
  if [[ -n $routes ]]; then
    while IFS=$'\t' read -r dst next_hop metric; do
      path=(dev "$uplink")
      if [[ $next_hop != - ]]; then
        path=(via "$next_hop" dev "$uplink" onlink)
      fi
      ip -4 route replace table "$route_table" "$dst" "${path[@]}" metric "$metric"
    done <<< "$routes"
  fi
  route_snapshot=$routes
}

start_uplink_routing() {
  local occupied
  occupied=$(ip -4 route show table "$route_table" 2>/dev/null || true)
  if [[ -n $occupied || -n $(ip -4 rule show pref "$route_priority") ||
        -n $(ip -4 rule show pref "$guard_priority") ]] ||
     nft list table ip "$guard_table" >/dev/null 2>&1; then
    fail '핫스팟 전용 라우팅 설정이 이미 사용 중입니다.'
  fi

  nft -f - <<RULES
table ip $guard_table {
  chain forward {
    type filter hook forward priority -5; policy accept;
    iifname "$bridge" oifname != "$uplink" drop
  }
}
RULES
  touch "$RUNTIME_DIRECTORY/uplink-guard"
  touch "$RUNTIME_DIRECTORY/uplink-routes"
  ip -4 rule add pref "$guard_priority" iif "$bridge" unreachable
  ip -4 rule add pref "$route_priority" iif "$bridge" lookup "$route_table"
  refresh_uplink_routes
}

stop_uplink_routing() {
  if [[ -e $RUNTIME_DIRECTORY/uplink-routes ]]; then
    ip -4 rule del pref "$route_priority" iif "$bridge" lookup "$route_table" 2>/dev/null || true
    ip -4 route flush table "$route_table" 2>/dev/null || true
    ip -4 rule del pref "$guard_priority" iif "$bridge" unreachable 2>/dev/null || true
  fi
  if [[ -e $RUNTIME_DIRECTORY/uplink-guard ]]; then
    nft delete table ip "$guard_table" 2>/dev/null || true
  fi
}

selected_dns() {
  local server
  local -a servers=()
  mapfile -t servers < <(nmcli -g IP4.DNS device show "$uplink" 2>/dev/null || true)
  if (( ! ${#servers[@]} )); then
    mapfile -t servers < <(awk '$1 == "nameserver" { print $2 }' /etc/resolv.conf)
  fi
  for server in "${servers[@]}"; do
    [[ $server =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && $server != 127.* && $server != 0.* ]] || continue
    if ip -4 -j route get "$server" from "${gateway%.*}.2" iif "$bridge" 2>/dev/null |
       jq -e --arg dev "$uplink" '.[0].dev == $dev' >/dev/null; then
      printf ',%s' "$server"
    fi
  done
}

create_hotspot_bridge() {
  if [[ -e /sys/class/net/$bridge ]] ||
     [[ -n $(ip -4 route show table all exact "$cidr") ||
        -n $(ip -4 route show table all proto kernel scope link match "$cidr") ||
        -n $(ip -4 route show table all proto kernel scope link root "$cidr") ]]; then
    fail "핫스팟 주소 $gateway 또는 같은 네트워크가 이미 사용 중입니다."
  fi
  ip link add name "$bridge" type bridge mcast_snooping 0
  touch "$RUNTIME_DIRECTORY/bridge"
  ip address add "$gateway/24" dev "$bridge"
  ip link set dev "$bridge" up
}

mdns_firewall() {
  local action=$1 iface
  [[ -r $runtime_path/mdns-uplink ]] || return 0
  read -r iface < "$runtime_path/mdns-uplink" || return 0
  valid_uplink "$iface" || return 0
  local -a rule=(-i "$iface" -p udp --sport 5353 --dport 5353
                 -m comment --comment "Noctalia hotspot mDNS" -j nixos-fw-accept)
  if [[ $action == remove ]]; then
    iptables -w -D nixos-fw "${rule[@]}" 2>/dev/null || true
  elif iptables -w -S nixos-fw >/dev/null 2>&1 &&
       ! iptables -w -C nixos-fw "${rule[@]}" 2>/dev/null; then
    iptables -w -I nixos-fw 1 "${rule[@]}"
  fi
}

refresh_mdns() {
  local iface=$uplink address selection=
  if [[ $iface == auto ]]; then
    iface=$(ip -4 -j route get 1.1.1.1 2>/dev/null | jq -r '.[0].dev // ""') || iface=
  fi
  if ! valid_uplink "$iface" ||
     ! ip -j link show dev "$iface" 2>/dev/null |
       jq -e '.[0].flags | (index("UP") != null and index("MULTICAST") != null)' >/dev/null; then
    iface=
  else
    address=$(ip -4 -j address show dev "$iface" 2>/dev/null | jq -r '.[0].addr_info[0].local // ""') || address=
    if [[ -n $address ]]; then
      selection="$iface:$address"
    else
      iface=
    fi
  fi
  if [[ $selection == "$mdns_current" ]] &&
     { [[ -z $iface ]] || kill -0 "$mdns_pid" 2>/dev/null; }; then
    return 0
  fi

  if [[ -n $mdns_pid ]]; then
    kill "$mdns_pid" 2>/dev/null || true
    wait "$mdns_pid" 2>/dev/null || true
  fi
  mdns_firewall remove
  if [[ -e $runtime_path/mdns-uplink ]]; then
    unlink "$runtime_path/mdns-uplink"
  fi
  mdns_current=$selection
  mdns_pid=
  if [[ -n $iface ]]; then
    printf '%s\n' "$iface" > "$runtime_path/mdns-uplink"
    mdns_firewall add
    mdns-repeater -f -u nobody -p "$runtime_path/mdns.pid" "$bridge" "$iface" >/dev/null &
    mdns_pid=$!
  fi
}
