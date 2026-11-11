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

    # SolidCraft parametric 3D CAD application (desktop and CLI).
    solidcraft = {
      url = "github:tangency-labs/solidcraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hancom Office 2020 (private repo fetched with the configured GitHub credentials). Only the
    # package definition lives there; the installer is downloaded by the build from a pinned URL.
    # It brings its own nixpkgs pins for 19.09 libraries.
    hnc2020.url = "git+https://github.com/kimseungsu-zzz/nixos-HNC2020";

    # ChatGPT Community (unofficial Linux build of the ChatGPT/Codex desktop app). It keeps its
    # own nixpkgs pin on purpose: its derivation patches the official Electron payload.
    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

    # Claude Desktop (official Linux beta from Anthropic's apt repo, packaged for Nix).
    claude-desktop.url = "github:poeck/claude-desktop-nix-flake";

    # Oh My Pi coding agent; keep upstream's toolchain pins for its native build.
    omp.url = "github:can1357/oh-my-pi";

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
      url = "git+https://github.com/wsuser1101/VMX-WPILib-2020-Archive.git?dir=nix-frc2020-vmx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ROS packages use the nixpkgs revision tested by the ROS overlay.
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";

    # PR #547 adds kernel input emulation for Niri; pin the patch revision.
    lan-mouse-niri = {
      url = "github:Manueloccorso/lan-mouse/a2dcf4dd940ef5d5fdda4d846b52c3001c3c37b4";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager desktop and application configuration.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hnc2020, nix-packages, nix-frc2020-vmx, nix-ros-overlay, lan-mouse-niri, codex-desktop-linux, claude-desktop, omp, zen-browser, noctalia, home-manager, solidcraft, ... }: {
    packages.x86_64-linux.lan-mouse-niri = import ./packages/lan-mouse.nix {
      inherit lan-mouse-niri;
      system = "x86_64-linux";
    };
    # nixos-rebuild switch --flake .#linux
    # `nixos` is an alias: nixos-rebuild looks up the *current* hostname.
    nixosConfigurations = rec {
      linux = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          codex-desktop-linux.nixosModules.default
          claude-desktop.nixosModules.default
          omp.nixosModules.default
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
              extraSpecialArgs = { inherit nix-packages noctalia nix-frc2020-vmx nix-ros-overlay lan-mouse-niri solidcraft; };
              # An existing config file is moved aside instead of aborting
              # the activation.
              backupFileExtension = "hm-backup";
              sharedModules = [
                ./home/noctalia-ap-list.nix
                ./home/wpilib-vmx.nix
                ./home/lan-mouse.nix
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
