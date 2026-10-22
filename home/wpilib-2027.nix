# WPILib 2027 alpha from the wpi2027-nix input:
#  - SysId, Glass, OutlineViewer, DataLogTool, WPICal and WPILib Utility (built from the allwpilib
#    sources), plus AdvantageScope, Choreo, PathPlanner and the Elastic dashboard;
#  - "WPILib VS Code 2027": VS Code with the WPILib extension and the C++, Java and Gradle
#    extensions robot projects use, kept apart from the regular VS Code (own settings and extensions).
{ pkgs, wpi2027-nix, ... }:

let
  wpi = wpi2027-nix.packages.${pkgs.stdenv.hostPlatform.system};

  vscodeWpilib = pkgs.vscode-with-extensions.override {
    vscodeExtensions = [ wpi.vscode-wpilib ] ++ (with pkgs.vscode-extensions; [
      ms-vscode.cpptools
      redhat.java
      vscjava.vscode-java-debug
      vscjava.vscode-java-dependency
      vscjava.vscode-java-test
      vscjava.vscode-gradle
    ]);
  };

  # The installed JDK is what the extension and Gradle find through JAVA_HOME.
  wpilibCode = pkgs.writeShellScriptBin "wpilibcode2027" ''
    export JAVA_HOME="${pkgs.jdk25}"
    export PATH="$JAVA_HOME/bin:$PATH"
    extensionsDir="''${XDG_CONFIG_HOME:-$HOME/.config}/wpilib-code-2027/extensions"
    mkdir -p "$extensionsDir"

    # vscode-with-extensions normally points --extensions-dir at its immutable
    # Nix store output. Mirror its bundled extensions into the writable profile
    # so users can install and update additional extensions alongside WPILib.
    bundledExtensionsDir="$(sed -n 's|^exec .* --extensions-dir \([^ ]*\) "\$@" *$|\1|p' "${vscodeWpilib}/bin/code")"
    if [ -z "$bundledExtensionsDir" ] || [ ! -d "$bundledExtensionsDir" ]; then
      echo "Could not locate the bundled WPILib VS Code extensions" >&2
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

    # Keep Nix-bundled extensions visible to VS Code while preserving extensions
    # installed by the user in this writable profile.
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
      --user-data-dir "''${XDG_CONFIG_HOME:-$HOME/.config}/wpilib-code-2027" \
      --extensions-dir "$extensionsDir" \
      "$@"
  '';

  wpilibCodeItem = pkgs.makeDesktopItem {
    name = "wpilibcode2027";
    desktopName = "WPILib VS Code 2027";
    exec = "wpilibcode2027 %F";
    icon = "vscode";
    categories = [ "Development" "IDE" ];
  };
in
{
  # The 2027 IDE remains available; shared desktop tools come from the 2026 suite to avoid
  # duplicate executable names in the Home Manager profile.
  home.packages = [ wpilibCode wpilibCodeItem pkgs.jdk25 ];
}
