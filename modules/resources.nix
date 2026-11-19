{ lib, ... }:

{
  zramSwap = {
    enable = true;
    memoryMax = 8 * 1024 * 1024 * 1024;
    algorithm = "zstd";
    priority = 100;
  };

  # Override the swap partition recorded by nixos-generate-config.
  # NixOS creates this Btrfs swap file on the first activation.
  swapDevices = lib.mkForce [
    {
      device = "/var/lib/swapfile";
      size = 4 * 1024;
      priority = 10;
    }
  ];

  boot.kernelParams = [
    "zswap.enabled=0"
    # The filesystems are declared explicitly. Prevent automatic activation of the old GPT swap.
    "systemd.gpt_auto=0"
  ];

  # With Intel HWP, performance requests the highest allowed P-state per core.
  powerManagement.cpuFreqGovernor = "performance";
  services.power-profiles-daemon.enable = false;
}
