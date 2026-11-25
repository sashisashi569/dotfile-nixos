# Generic Noctalia settings shared by every host.  Host files merge their own
# bar/monitor/wallpaper sections into this attrset with lib.recursiveUpdate.
{ ... }:

{
  # --- Theme ---
  theme = {
    mode = "auto";
    shell_mode = "follow";
    # Wallpaper-derived palette (Settings -> Theme -> Source).
    source = "wallpaper";
    builtin = "Noctalia";
    community_palette = "Oxocarbon";
    wallpaper_scheme = "m3-content";
  };

  # --- Shell ---
  shell = {
    font_family = "Noto Sans CJK JP";
    clipboard_enabled = true;
    # Noctalia's built-in polkit authentication agent.
    polkit_agent = true;
    external_ip_enabled = true;
    launch_apps_as_systemd_services = true;
    settings_expand_all_groups = true;
    settings_window_translucent = true;
    panel = {
      clipboard_placement = "attached";
      launcher_placement = "attached";
      polkit_placement = "attached";
      open_near_click_control_center = true;
      open_near_click_launcher = true;
      open_near_click_wallpaper = true;
    };
    screenshot.freeze_screen = false;
  };

  # No desktop widgets on any monitor.
  desktop_widgets.enabled = false;

  # Bar media widget: show the track progress bar.
  widget.media.show_progress = true;

  # --- Control center ---
  control_center = {
    hidden_tabs = [
      "media"
      "audio"
      "monitor"
      "system"
      "power"
      "network"
      "bluetooth"
      "weather"
      "calendar"
      "notifications"
      "screen-time"
    ];
    show_shortcut_labels = false;
    sidebar = "none";
    sidebar_section = "none";
    shortcuts = [
      { type = "dark_mode"; }
      { type = "caffeine"; }
      { type = "audio"; }
      { type = "mic_mute"; }
      { type = "wallpaper"; }
      { type = "notification"; }
    ];
  };
}
