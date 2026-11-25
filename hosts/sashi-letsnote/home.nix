# Host-specific home-manager configuration for sashi-letsnote.
{
  config,
  pkgs,
  ...
}:

{
  imports = [ ./noctalia.nix ];

  # Single-panel laptop: use the shared keybinds/appearance without any
  # sashi-main output sections.  Umbriel auto-configures eDP.
  xdg.configFile."umbriel/config.toml".text = import ../../sashi/lib/umbriel-base.nix {
    noctalia = config.programs.noctalia.package;
    kitty = pkgs.kitty;
  };
}
