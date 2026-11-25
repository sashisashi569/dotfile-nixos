# Generic Umbriel configuration shared by every host.  Output/monitor layout
# and per-workspace rules are appended by the host-specific home module.
#
# Umbriel's whole configuration lives in a single live-reloaded TOML file
# (~/.config/umbriel/config.toml).  Appearance (colors/palette), when the
# Noctalia template is enabled, is written by Noctalia itself to
# ~/.config/umbriel/noctalia.toml; that file is intentionally not managed here.
{
  noctalia,
  kitty,
}:

''
  # Check edits with `umbriel config validate`.
  # Reference: https://docs.noctalia.dev/umbriel/

  # Noctalia writes its rendered appearance template here (Settings ->
  # Templates -> Compositors -> Umbriel).  It is an optional include so a
  # missing file never turns into a startup error banner.
  [include.optional]
  files = ["noctalia.toml"]

  [general]
  autostart = [
    "fcitx5 -d",
  ]
  xwayland = true
  show_cheatsheet = true

  [input]
  middle_click_paste = false

  [input.keyboard]
  layout = "us"
  repeat_rate = 25
  repeat_delay = 600
  numlock_toggle = true

  [input.mouse]
  # Match the old Hyprland `accel_profile = "flat"` / `sensitivity = 0`.
  accel_profile = "flat"
  sensitivity = 0.0

  [input.touchpad]
  tap = true
  natural_scroll = false
  disable_while_typing = true

  [input.focus]
  follows_mouse = true
  # Hover-to-focus normally scrolls the strip to reveal the newly focused
  # column (default limit 0.5 viewport widths).  0.0 restricts focus to fully
  # visible windows and disables that auto-scroll.
  follows_mouse_max_scroll = 0.0

  [appearance]
  prefer_no_csd = true
  border_width = 2
  corner_radius = 10

  # Values recommended by Noctalia's Umbriel compositor-settings page.
  [appearance.blur]
  enabled = true
  optimized = true
  passes = 3
  radius = 3
  noise = 0.02
  brightness = 0.9
  contrast = 0.9
  saturation = 1.1

  [layout]
  mode = "scrolling"
  extent_presets = [0.333, 0.5, 0.667, 1.0]

  [layout.scrolling]
  default_extent_fraction = 0.5

  # ==========================================================================
  # Keybinds
  #
  # Umbriel has no per-output or per-layout keybind scoping (submaps are
  # manual), so this is one global table. Directional actions adapt to the
  # active workspace's layout mode:
  #   - scrolling (Niri-like): left/right = column, up/down = row
  #   - dwindle (Hyprland-like): Mod+arrows = focus, Mod+Shift+arrows = move
  # Actions: https://docs.noctalia.dev/umbriel/actions/
  # ==========================================================================
  [keybinds]

  # --- Applications / session ---
  "Mod+T" = { action = "spawn ${kitty}/bin/kitty", repeat = false }
  "Mod+Space" = "spawn ${noctalia}/bin/noctalia msg panel-toggle launcher"
  "Mod+Q" = { action = "window-close", repeat = false }
  "Mod+Escape" = "session-quit"
  "Mod+Shift+Escape" = { action = "shortcuts-inhibit-toggle", allow_when_inhibited = true, repeat = false }

  # --- Focus (directional; adaptive) ---
  "Mod+Left" = "window-focus-left"
  "Mod+Down" = "window-focus-down"
  "Mod+Up" = "window-focus-up"
  "Mod+Right" = "window-focus-right"
  "Mod+H" = "window-focus-left"
  "Mod+J" = "window-focus-down"
  "Mod+K" = "window-focus-up"
  "Mod+L" = "window-focus-right"
  "Mod+F1" = "window-focus-next"
  "Mod+Home" = "column-focus-first"
  "Mod+End" = "column-focus-last"

  # --- Window move (directional; adaptive) ---
  "Mod+Shift+Left" = "window-move-or-output-left"
  "Mod+Shift+Down" = "window-move-or-output-down"
  "Mod+Shift+Up" = "window-move-or-output-up"
  "Mod+Shift+Right" = "window-move-or-output-right"
  "Mod+Shift+H" = "window-move-or-output-left"
  "Mod+Shift+J" = "window-move-or-output-down"
  "Mod+Shift+K" = "window-move-or-output-up"
  "Mod+Shift+L" = "window-move-or-output-right"
  "Mod+Ctrl+Home" = "column-move-to-first"
  "Mod+Ctrl+End" = "column-move-to-last"

  # --- Output focus ---
  "Mod+Ctrl+Left" = "output-focus-left"
  "Mod+Ctrl+Right" = "output-focus-right"
  "Mod+Ctrl+H" = "output-focus-left"
  "Mod+Ctrl+L" = "output-focus-right"

  # --- Workspaces (vertical axis: Up = previous, Down = next) ---
  "Mod+Ctrl+Up" = "workspace-previous"
  "Mod+Ctrl+Down" = "workspace-next"
  "Mod+U" = "workspace-next"
  "Mod+I" = "workspace-previous"
  "Mod+Page_Down" = "workspace-next"
  "Mod+Page_Up" = "workspace-previous"
  "Mod+Shift+Page_Down" = "workspace-move-down"
  "Mod+Shift+Page_Up" = "workspace-move-up"
  "Mod+Shift+U" = "workspace-move-down"
  "Mod+Shift+I" = "workspace-move-up"
  "Mod+1" = "workspace-switch 1"
  "Mod+2" = "workspace-switch 2"
  "Mod+3" = "workspace-switch 3"
  "Mod+4" = "workspace-switch 4"
  "Mod+5" = "workspace-switch 5"
  "Mod+6" = "workspace-switch 6"
  "Mod+7" = "workspace-switch 7"
  "Mod+8" = "workspace-switch 8"
  "Mod+9" = "workspace-switch 9"
  "Mod+Ctrl+1" = "column-move-to-workspace 1"
  "Mod+Ctrl+2" = "column-move-to-workspace 2"
  "Mod+Ctrl+3" = "column-move-to-workspace 3"
  "Mod+Ctrl+4" = "column-move-to-workspace 4"
  "Mod+Ctrl+5" = "column-move-to-workspace 5"
  "Mod+Ctrl+6" = "column-move-to-workspace 6"
  "Mod+Ctrl+7" = "column-move-to-workspace 7"
  "Mod+Ctrl+8" = "column-move-to-workspace 8"
  "Mod+Ctrl+9" = "column-move-to-workspace 9"
  "Mod+Ctrl+Page_Down" = "column-move-to-workspace-next"
  "Mod+Ctrl+Page_Up" = "column-move-to-workspace-previous"
  "Mod+Ctrl+U" = "column-move-to-workspace-next"
  "Mod+Ctrl+I" = "column-move-to-workspace-previous"

  # --- Window / column sizing (extent presets include 1.0) ---
  "Mod+R" = "window-cycle-primary-extent"
  "Mod+Shift+R" = "window-cycle-primary-extent-back"
  "Mod+Ctrl+Shift+R" = "window-cycle-secondary-extent"
  "Mod+Ctrl+R" = "window-cycle-secondary-extent-back"
  "Mod+Minus" = "window-modify-primary-extent -0.1"
  "Mod+Equal" = "window-modify-primary-extent 0.1"
  "Mod+Shift+Minus" = "window-modify-secondary-extent -0.1"
  "Mod+Shift+Equal" = "window-modify-secondary-extent 0.1"

  # --- Window state ---
  "Mod+Shift+F" = { action = "window-toggle-fullscreen", repeat = false }
  "Mod+C" = "column-center"
  "Mod+V" = { action = "window-toggle-floating", repeat = false }
  "Mod+Shift+V" = { action = "window-focus-switch-floating", repeat = false }
  "Mod+P" = { action = "window-toggle-pinned", repeat = false }
  "Mod+O" = { action = "overview-toggle", repeat = false }

  # --- Consume / expel windows ---
  "Mod+BracketLeft" = "window-consume-or-expel-left"
  "Mod+BracketRight" = "window-consume-or-expel-right"
  "Mod+Comma" = "window-consume-left"
  "Mod+Period" = "window-consume-right"

  # Scratchpad. Mod+Space opens the launcher, so these use `grave`.
  "Mod+grave" = "scratchpad-toggle"
  "Mod+Shift+grave" = { action = "window-move-to-scratchpad", repeat = false }
  "Mod+Ctrl+grave" = { action = "window-restore-from-scratchpad", repeat = false }
  "Mod+Tab" = "scratchpad-focus-next"

  # Screenshots via Noctalia's built-in capture.
  "Mod+Shift+S" = "spawn ${noctalia}/bin/noctalia msg screenshot-fullscreen"
  "Mod+Ctrl+S" = "spawn ${noctalia}/bin/noctalia msg screenshot-region"
  "Mod+Ctrl+Shift+S" = "spawn ${noctalia}/bin/noctalia msg screenshot-fullscreen pick"

  # Media / brightness keys drive the Noctalia OSDs.
  "XF86AudioRaiseVolume" = "spawn ${noctalia}/bin/noctalia msg volume-up"
  "XF86AudioLowerVolume" = "spawn ${noctalia}/bin/noctalia msg volume-down"
  "XF86AudioMute" = "spawn ${noctalia}/bin/noctalia msg volume-mute"
  "XF86MonBrightnessUp" = "spawn ${noctalia}/bin/noctalia msg brightness-up"
  "XF86MonBrightnessDown" = "spawn ${noctalia}/bin/noctalia msg brightness-down"

  # Blur all windows.
  [[window_rule]]
  blur = true
  blur_optimized = false

  [[window_rule]]
  match.app_id = "^dev.noctalia.Noctalia$"
  default_floating = true
  default_floating_size_px = { width = 1020, height = 900 }

  [[layer_rule]]
  match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\"]*)$"
  blur = true
  blur_ignore_alpha = 0.5
  blur_popups = true
  blur_optimized = false

  [hot_corners.top_left]
  enabled = true
  delay_ms = 500
  action = "overview-open"
''
