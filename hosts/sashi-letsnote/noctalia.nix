# sashi-letsnote's Noctalia settings: a single top bar with battery and
# brightness widgets.  Generic shell behavior comes from
# ../../sashi/lib/noctalia-base.nix.
{ lib, ... }:

let
  base = import ../../sashi/lib/noctalia-base.nix { };
in
{
  programs.noctalia.settings = lib.recursiveUpdate base {
    location.address = "Japan,Nagoya";

    bar.default = {
      position = "top";
      thickness = 32;
      margin_ends = 0;
      background_opacity = 0.66;
      start = [
        "launcher"
        "workspaces"
        "sysmon"
      ];
      center = [ "clock" ];
      end = [
        "media"
        "tray"
        "network"
        "bluetooth"
        "volume"
        "brightness"
        "battery"
        "clipboard"
        "control-center"
      ];
    };
  };
}
