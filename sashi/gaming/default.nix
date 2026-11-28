# Gaming-only home packages.  The system-side Steam/AAGL stack is enabled by
# sashi.desktop.gaming.enable in system/desktop-environment.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lutris
    bottles
    discord
    prismlauncher
    # osu-lazer (source build) cannot submit scores or play multiplayer;
    # osu-lazer-bin is the official build with those features.
    osu-lazer-bin
  ];
}
