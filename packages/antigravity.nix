{ pkgs, antigravity ? pkgs.antigravity }:
let
  browserTools = pkgs.writeShellScriptBin "xdg-open" ''
    case "''${1:-}" in
      http://*|https://*) exec ${pkgs.firefox}/bin/firefox "$@" ;;
      *) exec ${pkgs.xdg-utils}/bin/xdg-open "$@" ;;
    esac
  '';
in
pkgs.symlinkJoin {
  name = "antigravity-firefox";
  paths = [ antigravity ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    if [ ! -e "$out/bin/antigravity" ]; then
      ln -s "$out/bin/antigravity-ide" "$out/bin/antigravity"
    fi
    wrapProgram $out/bin/antigravity \
      --set BROWSER ${pkgs.firefox}/bin/firefox \
      --prefix PATH : ${browserTools}/bin
    for desktop in $out/share/applications/*.desktop; do
      target=$(readlink -f "$desktop")
      rm "$desktop"
      cp "$target" "$desktop"
      chmod u+w "$desktop"
      substituteInPlace "$desktop" --replace "Exec=antigravity-ide" "Exec=antigravity"
      substituteInPlace "$desktop" --replace '${antigravity}/bin/antigravity' "$out/bin/antigravity"
    done
  '';
}
