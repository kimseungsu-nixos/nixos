# WPILib VMX 2020: VS Code, the Elastic dashboard and a shell, run natively from the tree that
# WPILibInstaller-Avalonia installed in ~/wpilib/2020_vmx (nix-packages: wpilib-vmx).
{ pkgs, nix-packages, ... }:

{
  home.packages = [ nix-packages.packages.${pkgs.stdenv.hostPlatform.system}.wpilib-vmx ];
}
