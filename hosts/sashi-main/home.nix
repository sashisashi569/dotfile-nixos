# Host-specific home-manager configuration for sashi-main.
#
# Shared user configuration lives in ../../sashi/core; gaming packages live in
# ../../sashi/gaming.  Only the three-monitor Umbriel/Noctalia layout and
# wallpaper choices are desktop-specific.
{
  imports = [
    ./umbriel.nix
    ./noctalia.nix
  ];
}
