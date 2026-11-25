# Gaming-only home packages and Flatpaks.  The system-side Steam/AAGL stack is
# enabled by sashi.desktop.gaming.enable in system/desktop-environment.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lutris
    bottles
  ];

  services.flatpak.packages = [
    {
      appId = "com.discordapp.Discord";
      origin = "flathub";
    }
    {
      appId = "com.github.tchx84.Flatseal";
      origin = "flathub";
    }
    {
      appId = "org.prismlauncher.PrismLauncher";
      origin = "flathub";
    }
    {
      appId = "sh.ppy.osu";
      origin = "flathub";
    }
  ];
}
