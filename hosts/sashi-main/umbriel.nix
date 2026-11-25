# sashi-main's three-monitor layout on top of the shared Umbriel config.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  noctalia = config.programs.noctalia.package;

  # Umbriel has a single global layout plus per-workspace rules; there is no
  # per-output layout key.  Emit one index-based rule per workspace position
  # on the two portrait side panels so they get a Hyprland-style dwindle
  # layout while the Dell G2725D keeps the Niri-style scrolling default.
  #
  # Outputs are keyed by EDID monitor identity, not connector name.  Disabling
  # the AMD iGPU shifted the NVIDIA connector numbering down one; identity
  # keys survive that.
  dwindleOutputs = [
    "AOC G2490W1G4 PIOMAHA130206"
    "Dell Inc. DELL S2421NX 4T1SD34"
  ];

  workspaceLayoutRules = lib.concatMapStrings (
    idx:
    lib.concatMapStrings (out: ''
      [[workspace]]
      index = ${toString idx}
      output = "${out}"
      layout.mode = "dwindle"
    '') dwindleOutputs
  ) (lib.range 1 16);
in
{
  xdg.configFile."umbriel/config.toml".text = ''
    ${import ../../sashi/lib/umbriel-base.nix {
      inherit noctalia;
      kitty = pkgs.kitty;
    }}

    # Monitors, left to right: AOC G2490W1G4 (portrait) | Dell G2725D |
    # Dell S2421NX (portrait).  Keyed by EDID monitor identity so settings
    # follow each panel between ports.  Positions are pinned so the order
    # survives replug, and the G2725D runs at its 180 Hz mode instead of the
    # 60 Hz preferred mode.  The AOC is portrait turned 90° left (transform
    # "90"), the S2421NX 90° right (transform "270").  A rotated 1920x1080
    # panel is 1080 logical px wide, so x-offsets are 0, 1080, and 3640.
    [output."AOC G2490W1G4 PIOMAHA130206"]
    mode = "1920x1080@60"
    position = [0, 0]
    scale = 1.0
    transform = "90"

    [output."Dell Inc. DELL G2725D JFL6S34"]
    mode = "2560x1440@180"
    position = [1080, 0]
    scale = 1.0
    # Gaming panel: allow adaptive sync and async page flips, but only for
    # eligible fullscreen windows.
    vrr = "fullscreen"
    tearing = true

    [output."Dell Inc. DELL S2421NX 4T1SD34"]
    mode = "1920x1080@60"
    position = [3640, 0]
    scale = 1.0
    transform = "270"

    # Hyprland-style dynamic tiling for the two side monitors.
    ${workspaceLayoutRules}
  '';
}
