{ pkgs }:
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
  paths = [ pkgs.antigravity ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/antigravity \
      --set BROWSER ${pkgs.firefox}/bin/firefox \
      --prefix PATH : ${browserTools}/bin
    for desktop in $out/share/applications/*.desktop; do
      target=$(readlink -f "$desktop")
      rm "$desktop"
      cp "$target" "$desktop"
      chmod u+w "$desktop"
      substituteInPlace "$desktop" --replace '${pkgs.antigravity}/bin/antigravity' "$out/bin/antigravity"
    done
  '';
}
