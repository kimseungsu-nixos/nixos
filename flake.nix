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

    # ROS 2 Elastic Dashboard uses the Flutter toolchain pinned by its own flake.
    ros2-elastic-dashboard.url = "git+https://github.com/kimseungsu-zzz/ros2_elastic_dashboard.git";

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

  outputs = { nixpkgs, hnc2020, nix-packages, nix-frc2020-vmx, nix-ros-overlay, ros2-elastic-dashboard, lan-mouse-niri, codex-desktop-linux, claude-desktop, omp, zen-browser, noctalia, home-manager, solidcraft, ... }:
  let
    rosPkgs = nix-ros-overlay.legacyPackages.x86_64-linux;
    ros = rosPkgs.rosPackages.lyrical;
    inherit (nix-ros-overlay.inputs.nixpkgs.legacyPackages.x86_64-linux) lib makeWrapper python3 symlinkJoin;
    rosboard = ros.buildRosPackage {
      pname = "ros-lyrical-rosboard";
      version = "1.3.1";
      src = (builtins.fetchTree {
        type = "github";
        owner = "dheera";
        repo = "rosboard";
        # Includes the NumPy 2 PointCloud2 fix.
        rev = "4407d8e629e35e26547bbf8f9f62bb29e7606614";
      }).outPath;
      buildType = "ament_python";
      propagatedBuildInputs = [
        ros.rclpy
        ros.rosidl-runtime-py
      ] ++ (with ros.python3Packages; [ numpy pillow psutil tornado ]);

      postInstall = ''
        cp -r launch "$out/share/rosboard/"
        test -x "$out/lib/rosboard/rosboard_node"
        test -f "$out/share/ament_index/resource_index/packages/rosboard"
        test -f "$out/${ros.python3.sitePackages}/rosboard/html/index.html"
      '';
    };
    rosPaths = with ros; [
      desktop
      ros2-control
      ros2-controllers
      hardware-interface
      controller-manager
      pluginlib
      rclcpp-lifecycle
      gpio-controllers
    ];
    rosEnv = ros.buildEnv { paths = rosPaths ++ [ rosboard ]; };
    rosUnderlay = ros.buildEnv {
      underlay = true;
      paths = [ rosPkgs.colcon ros.ament-cmake-core ros.python-cmake-module ] ++ rosPaths;
      # Colcon chains the underlay into each workspace's generated setup scripts.
      postBuild = ''
        cat > "$out/local_setup.sh" <<'EOF'
        _nix_ros_append() {
          eval '_nix_ros_path=''${'"$1"'-}'
          case ":$_nix_ros_path:" in
            *":$2:"*) ;;
            *) export "$1=''${_nix_ros_path:+$_nix_ros_path:}$2" ;;
          esac
        }

        _nix_ros_append PATH @out@/bin
        _nix_ros_append AMENT_PREFIX_PATH @out@
        _nix_ros_append CMAKE_PREFIX_PATH @out@
        _nix_ros_append LD_LIBRARY_PATH @out@/lib
        _nix_ros_append PYTHONPATH @out@/${python3.sitePackages}
        _nix_ros_append ROS_PACKAGE_PATH @out@/share
        _nix_ros_append GZ_CONFIG_PATH @out@/share/gz
        export ROS_DISTRO=${ros.ros-environment.rosDistro}
        export ROS_VERSION=${toString ros.ros-environment.rosVersion}
        export ROS_PYTHON_VERSION=${lib.versions.major python3.version}
        unset -f _nix_ros_append
        unset _nix_ros_path
        EOF
        substituteInPlace "$out/local_setup.sh" --replace-fail @out@ "$out"
        ln -sfn local_setup.sh "$out/local_setup.bash"
        ln -sfn local_setup.sh "$out/local_setup.zsh"
      '';
    };
    rosDevShell = nix-ros-overlay.devShells.x86_64-linux.example-ros2-desktop-lyrical.overrideAttrs (_: {
      nativeBuildInputs = [ rosUnderlay ];
    });
    colconRos2 = rosDevShell.stdenv.mkDerivation {
      name = "colcon-ros2";
      nativeBuildInputs = rosDevShell.nativeBuildInputs ++ [ makeWrapper ];
      inherit (rosDevShell) buildInputs;
      buildCommand = ''
        # Keep the ROS development shell's toolchain and dependency paths local to colcon.
        wrapperArgs=(--prefix PATH : "$PATH")
        for var in CMAKE_PREFIX_PATH CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH \
            NIXPKGS_CMAKE_PREFIX_PATH PKG_CONFIG_PATH; do
          wrapperArgs+=(--suffix "$var" : "''${!var-}")
        done
        makeWrapper "$(command -v colcon)" "$out/bin/colcon" \
          "''${wrapperArgs[@]}" \
          --suffix NIX_CFLAGS_COMPILE ' ' "''${NIX_CFLAGS_COMPILE-}" \
          --suffix NIX_LDFLAGS ' ' "''${NIX_LDFLAGS-}"
      '';
    };
  in {
    packages.x86_64-linux.lan-mouse-niri = import ./packages/lan-mouse.nix {
      inherit lan-mouse-niri;
      system = "x86_64-linux";
    };
    packages.x86_64-linux.colcon-ros2 = colconRos2;
    packages.x86_64-linux.rosboard = rosboard;
    packages.x86_64-linux.ros2 = symlinkJoin {
      name = "ros2-lyrical";
      paths = [ rosEnv colconRos2 ];
    };
    devShells.x86_64-linux.ros2 = rosDevShell;

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
              extraSpecialArgs = { inherit nix-packages noctalia nix-frc2020-vmx rosEnv ros2-elastic-dashboard lan-mouse-niri solidcraft colconRos2; };
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
