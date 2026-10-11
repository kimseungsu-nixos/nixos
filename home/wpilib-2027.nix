# WPILib 2027 alpha tools (SysId, Glass, OutlineViewer, DataLogTool, WPICal, WPILib Utility) from the
# wpi2027-nix input. They are built from the allwpilib sources.
{ pkgs, wpi2027-nix, ... }:

let
  wpi = wpi2027-nix.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = with wpi; [
    datalogtool
    glass
    outlineviewer
    sysid
    wpical
    wpilib-utility
  ];
}
