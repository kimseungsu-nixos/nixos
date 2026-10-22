# WPILib 2026 VS Code with its matching extension and an isolated writable profile.
{ pkgs, ... }:

let
  vscodeWpilib = pkgs.vscode-with-extensions.override {
    vscodeExtensions = [ pkgs.vscode-extensions.wpilibsuite.vscode-wpilib ] ++ (with pkgs.vscode-extensions; [
      ms-vscode.cpptools
      redhat.java
      vscjava.vscode-java-debug
      vscjava.vscode-java-dependency
      vscjava.vscode-java-test
      vscjava.vscode-gradle
    ]);
  };

  wpilibCode = pkgs.writeShellScriptBin "wpilibcode2026" ''
    export JAVA_HOME="${pkgs.jdk17}"
    export PATH="$JAVA_HOME/bin:$PATH"
    extensionsDir="''${XDG_CONFIG_HOME:-$HOME/.config}/wpilib-code-2026/extensions"
    mkdir -p "$extensionsDir"

    bundledExtensionsDir="$(sed -n 's|^exec .* --extensions-dir \([^ ]*\) "\$@" *$|\1|p' "${vscodeWpilib}/bin/code")"
    if [ -z "$bundledExtensionsDir" ] || [ ! -d "$bundledExtensionsDir" ]; then
      echo "Could not locate the bundled WPILib 2026 VS Code extensions" >&2
      exit 1
    fi
    for extension in "$bundledExtensionsDir/"*; do
      extensionName="$(basename "$extension")"
      [ "$extensionName" = "extensions.json" ] && continue
      destination="$extensionsDir/$extensionName"
      if [ "''${extensionName#wpilibsuite.vscode-wpilib-}" != "$extensionName" ]; then
        # WPILib rewrites project files after copying a template. The Nix store
        # makes those source directories read-only, and its copy preserves
        # that mode, so give the project copy a writable extension source.
        if [ -L "$destination" ]; then
          rm "$destination"
        fi
        if [ ! -e "$destination" ]; then
          cp -RL "$extension" "$destination"
        fi
        chmod -R u+rwX "$destination/resources"
      elif [ -L "$destination" ]; then
        ln -sfn "$extension" "$destination"
      elif [ ! -e "$destination" ]; then
        ln -s "$extension" "$destination"
      fi
    done

    bundledMetadata="$bundledExtensionsDir/extensions.json"
    userMetadata="$extensionsDir/extensions.json"
    if [ -f "$userMetadata" ]; then
      "${pkgs.jq}/bin/jq" -s \
        '.[0] + .[1] | reduce .[] as $extension ({}; .[$extension.identifier.id] = $extension) | [.[]]' \
        "$bundledMetadata" "$userMetadata" > "$extensionsDir/extensions.json.tmp"
      mv "$extensionsDir/extensions.json.tmp" "$userMetadata"
    else
      cp "$bundledMetadata" "$userMetadata"
    fi

    exec ${vscodeWpilib}/bin/code \
      --user-data-dir "''${XDG_CONFIG_HOME:-$HOME/.config}/wpilib-code-2026" \
      --extensions-dir "$extensionsDir" \
      "$@"
  '';

  wpilibCodeItem = pkgs.makeDesktopItem {
    name = "wpilibcode2026";
    desktopName = "WPILib VS Code 2026";
    exec = "wpilibcode2026 %F";
    icon = "vscode";
    categories = [ "Development" "IDE" ];
  };
in
{
  # Keep JDK 17 scoped to this IDE wrapper; the WPILib 2027 IDE uses JDK 25 globally.
  home.packages = [ wpilibCode wpilibCodeItem ];
}
