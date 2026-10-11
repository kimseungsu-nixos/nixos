{
  description = "linux NixOS system";

  # Official Noctalia cache; avoids compiling its Qt shell locally.
  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };

  inputs = {
    # Matches system.stateVersion in configuration.nix.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Hancom Office 2020 (private repo, fetched with the `gh auth login` credentials like the other
    # private inputs). Only the package definition lives there; the installer is downloaded by the
    # build from a pinned URL. It brings its own nixpkgs pins (the app needs 19.09 libraries).
    hnc2020.url = "git+https://github.com/kimseungsu-zzz/nixos-HNC2020";

    # ChatGPT Community (unofficial Linux build of the ChatGPT/Codex desktop app). It keeps its
    # own nixpkgs pin on purpose: its derivation patches the official Electron payload.
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

    # Claude Desktop (official Linux beta from Anthropic's apt repo, packaged for Nix).
    claude-desktop.url = "github:poeck/claude-desktop-nix-flake";

    # Zen Browser, packaged for Nix with a Home Manager module.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Complete desktop shell for the Niri session (bar, launcher, notifications, controls).
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    # Private monorepo: Studica Hardware Manager, Titan Config, KakaoTalk (packages + NixOS
    # modules). Fetched over HTTPS with the gh credentials, like the other private inputs.
    nix-packages = {
      url = "git+https://github.com/kimseungsu-zzz/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # WPILib VMX 2020 archive: the FHS runtime package for the tree WPILibInstaller-Avalonia installs.
    nix-frc2020-vmx = {
      url = "git+https://github.com/VMX-WPILib-2020-Archive/nix-frc2020-vmx.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FRC tools (SysId, Glass, PathPlanner, ...) ported to the WPILib 2027 alpha.
    wpi2027-nix = {
      url = "git+https://github.com/W4Studica/wpi2027-nix.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager desktop and application configuration.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hnc2020, nix-packages, nix-frc2020-vmx, wpi2027-nix, codex-desktop-linux, claude-desktop, zen-browser, noctalia, home-manager, ... }: {
    # nixos-rebuild switch --flake .#linux
    # `nixos` is an alias: nixos-rebuild looks up the *current* hostname.
    nixosConfigurations = rec {
      linux = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          codex-desktop-linux.nixosModules.default
          claude-desktop.nixosModules.default
          hnc2020.nixosModules.default
          nix-packages.nixosModules.studica-hardware-manager
          nix-packages.nixosModules.titan-config
          nix-packages.nixosModules.kakaotalk
          nix-packages.nixosModules.legacylauncher
          nix-packages.nixosModules.zapret-gui
          { nix.settings.experimental-features = [ "nix-command" "flakes" ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit nix-packages noctalia nix-frc2020-vmx wpi2027-nix; };
              # An existing config file is moved aside instead of aborting
              # the activation.
              backupFileExtension = "hm-backup";
              sharedModules = [
                ./home/fusion360.nix
                ./home/noctalia-ap-list.nix
                ./home/wpilib-vmx.nix
                ./home/wpilib-2027.nix
                zen-browser.homeModules.beta
                noctalia.homeModules.default
              ];
              users.linux = import ./home.nix;
            };
          }
        ];
      };
      nixos = linux;
    };
  };
}
