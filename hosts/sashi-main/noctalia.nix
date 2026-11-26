# sashi-main's Noctalia shell settings: three-monitor bar, wallpapers and
# lockscreen widgets.  Generic shell behavior comes from
# ../../sashi/lib/noctalia-base.nix.
{ lib, ... }:

let
  base = import ../../sashi/lib/noctalia-base.nix { };
in
{
  programs.noctalia.settings = lib.recursiveUpdate base {
    location.address = "Japan,Nagoya";

    # --- Bar (Dell G2725D only; the two portrait side panels disabled) ---
    # Matched by a token in the output description (not the connector name)
    # so it survives connector renumbering.
    bar.default = {
      position = "top";
      thickness = 34;
      margin_ends = 360;
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
      monitor = {
        aoc = {
          match = "AOC";
          enabled = false;
        };
        dellS2421NX = {
          match = "S2421NX";
          enabled = false;
        };
      };
    };

    # --- Wallpaper (per-monitor directories; G2725D landscape, sides portrait) ---
    wallpaper = {
      directory = "/home/sashi/Wallpapers";
      per_monitor_directories = true;
      transition_on_startup = true;
      automation = {
        enabled = true;
        interval_seconds = 720;
      };
      default.path = "/home/sashi/Wallpapers/Landspace/dsallstar2_wallpaper_3840x2160.jpg";
      monitor = {
        "AOC" = {
          directory = "/home/sashi/Wallpapers/Portrait";
        };
        "G2725D" = {
          directory = "/home/sashi/Wallpapers/Landspace";
        };
        "S2421NX" = {
          directory = "/home/sashi/Wallpapers/Portrait";
        };
      };
    };

    # --- Lockscreen widgets (currently disabled, layout kept) ---
    lockscreen_widgets = {
      enabled = false;
      widget_order = [
        "lockscreen-login-box@DP-3"
        "lockscreen-login-box@HDMI-A-1"
        "lockscreen-login-box@DP-1"
      ];
      grid = {
        cell_size = 16;
        major_interval = 4;
        visible = true;
      };
      widget = {
        "lockscreen-login-box@DP-1" = {
          type = "login_box";
          output = "DP-1";
          cx = 540.0;
          cy = 1596.4444580078125;
          box_width = 810.0;
          box_height = 196.0;
          placement_width = 1080.0;
          placement_height = 1920.0;
          rotation = 0.0;
          settings = {
            background_color = "surface_container";
            background_opacity = 0.88;
            background_radius = 12.0;
            center_password_text = false;
            input_opacity = 1.0;
            input_radius = 6.0;
            layout = "regular";
            show_caps_lock = true;
            show_keyboard_layout = true;
            show_login_button = true;
            show_media = true;
            show_session_buttons = true;
            show_unlock_hint = true;
            show_weather = true;
          };
        };
        "lockscreen-login-box@DP-3" = {
          type = "login_box";
          output = "DP-3";
          cx = 1280.0;
          cy = 1258.0;
          box_width = 810.0;
          box_height = 196.0;
          placement_width = 2560.0;
          placement_height = 1440.0;
          rotation = 0.0;
          settings = {
            background_color = "surface_container";
            background_opacity = 0.88;
            background_radius = 12.0;
            center_password_text = false;
            input_opacity = 1.0;
            input_radius = 6.0;
            layout = "regular";
            show_caps_lock = true;
            show_keyboard_layout = true;
            show_login_button = true;
            show_media = true;
            show_session_buttons = true;
            show_unlock_hint = true;
            show_weather = true;
          };
        };
        "lockscreen-login-box@HDMI-A-1" = {
          type = "login_box";
          output = "HDMI-A-1";
          cx = 540.0;
          cy = 1596.4444580078125;
          box_width = 810.0;
          box_height = 196.0;
          placement_width = 1080.0;
          placement_height = 1920.0;
          rotation = 0.0;
          settings = {
            background_color = "surface_container";
            background_opacity = 0.88;
            background_radius = 12.0;
            center_password_text = false;
            input_opacity = 1.0;
            input_radius = 6.0;
            layout = "regular";
            show_caps_lock = true;
            show_keyboard_layout = true;
            show_login_button = true;
            show_media = true;
            show_session_buttons = true;
            show_unlock_hint = true;
            show_weather = true;
          };
        };
      };
    };
  };
}
