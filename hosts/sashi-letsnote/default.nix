# sashi-letsnote: laptop for browsing and development.
#
# No NVIDIA module and no gaming stack.  The same Noctalia Family desktop
# (Umbriel + Noctalia + Noctalia Greeter) is used as on sashi-main.
{
  config,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../system/boot
    ../../system/core
    ../../system/develop
    ../../system/network
    ../../system/graphics
    ../../system/desktop-environment
  ];

  networking.hostName = "sashi-letsnote";

  system.stateVersion = "26.05";

  home-manager.users.sashi.imports = [
    ../../sashi/core
    ./home.nix
  ];
}
