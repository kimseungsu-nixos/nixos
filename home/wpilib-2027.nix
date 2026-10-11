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
    exec ${vscodeWpilib}/bin/code --user-data-dir "''${XDG_CONFIG_HOME:-$HOME/.config}/wpilib-code-2027" "$@"
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
  home.packages = (with wpi; [
    datalogtool
    glass
    outlineviewer
    sysid
    wpical
    wpilib-utility
    advantagescope
    choreo
    pathplanner
    elastic-dashboard
  ]) ++ [ wpilibCode wpilibCodeItem pkgs.jdk25 ];
}
