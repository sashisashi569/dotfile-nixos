# sashi-main: desktop, gaming, development and compute host.
{
  config,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./keychron.nix
    ./fiio.nix

    ../../system/boot
    ../../system/core
    ../../system/develop
    ../../system/network
    ../../system/graphics
    ../../system/nvidia
    ../../system/desktop-environment
  ];

  networking.hostName = "sashi-main";

  system.stateVersion = "26.05";

  # Compute host: libvirt/QEMU and virt-manager.
  sashi.develop.virtualisation.enable = true;

  # Gaming: Steam, Gamescope, AAGL launchers.
  sashi.desktop.gaming.enable = true;
  # Pin Gamescope's Vulkan device to the NVIDIA GPU (PCI ID from
  # /sys/class/drm/card2/device/{vendor,device}).
  sashi.desktop.gamescopeVulkanDevice = "10de:2882";

  home-manager.users.sashi.imports = [
    ../../sashi/core
    ../../sashi/gaming
    ./home.nix
  ];
}
