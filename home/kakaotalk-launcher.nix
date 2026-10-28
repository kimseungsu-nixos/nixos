{ pkgs }:

let
  wine = pkgs.wineWow64Packages.stable;
  fonts = pkgs.makeFontsConf {
    fontDirectories = with pkgs; [ nanum noto-fonts-cjk-sans noto-fonts-cjk-serif d2coding ];
  };
in
# Override the system launcher, which kills the whole prefix on every click.
# Focus a mapped Niri window before invoking Wine: KakaoTalk toggles visibility
# on repeat invocation. Remap hidden windows before starting a new instance.
pkgs.writeShellScriptBin "kakaotalk" ''
  export WINEPREFIX="''${WINEPREFIX:-$HOME/.local/share/kakaotalk}"
  export XMODIFIERS="@im=kime"
  export WINEARCH=win64
  export LANG=ko_KR.UTF-8
  export LC_ALL=ko_KR.UTF-8
  export FONTCONFIG_FILE=${fonts}
  export WINEDLLOVERRIDES="winemenubuilder.exe=d"
  exe="$WINEPREFIX/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe"
  if [ ! -f "$exe" ]; then
    echo "KakaoTalk 미설치. 설치 파일 실행: kakaotalk-install <KakaoTalk_Setup.exe>"
    exit 1
  fi
  if [ -n "''${NIRI_SOCKET:-}" ] && [ "$#" -eq 0 ]; then
    window_id=$(${pkgs.niri}/bin/niri msg --json windows 2>/dev/null | ${pkgs.jq}/bin/jq -r '
      map(select(.app_id == "kakaotalk.exe"))
      | (map(select(.title == "카카오톡" or .title == "KakaoTalk")) + .)
      | .[0].id // empty
    ')
    if [ -n "$window_id" ]; then
      exec ${pkgs.niri}/bin/niri msg action focus-window --id "$window_id"
    fi
  fi
  # A Wine process can remain alive after its X11 main window is unmapped.
  # Remap that window directly; repeat EXE launches do not reliably restore it.
  if [ -n "''${DISPLAY:-}" ] && [ "$#" -eq 0 ]; then
    for xid in $(${pkgs.xdotool}/bin/xdotool search --class '^kakaotalk\.exe$' 2>/dev/null); do
      title=$(${pkgs.xdotool}/bin/xdotool getwindowname "$xid" 2>/dev/null)
      case "$title" in
        카카오톡|KakaoTalk)
          exec ${pkgs.xdotool}/bin/xdotool windowmap "$xid"
          ;;
      esac
    done
  fi
  # Wine creates its input contexts at startup. Ensure the XIM server is
  # registered before starting a fresh process, rather than relying on late reconnects.
  if [ -n "''${DISPLAY:-}" ]; then
    ${pkgs.systemd}/bin/systemctl --user start kime-xim.service 2>/dev/null || true
    for attempt in {1..30}; do
      if ${pkgs.xprop}/bin/xprop -root XIM_SERVERS 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '@server=kime'; then
        break
      fi
      sleep 0.1
    done
  fi
  exec ${wine}/bin/wine "$exe" "$@"
''
