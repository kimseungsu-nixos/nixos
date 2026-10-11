# WPILib VMX 2020: VS Code, the Elastic dashboard and a shell, run natively from the tree that
# WPILibInstaller-Avalonia installed in ~/wpilib/2020_vmx (package from the nix-frc2020-vmx input).
{ pkgs, nix-frc2020-vmx, ... }:

{
  home.packages = [ nix-frc2020-vmx.packages.${pkgs.stdenv.hostPlatform.system}.wpilib2020-vmx ];
}
