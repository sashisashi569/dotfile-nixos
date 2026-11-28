# Noctalia Family desktop: Umbriel (compositor) + Noctalia (shell) +
# Noctalia Greeter (greetd), plus PipeWire/GStreamer, printing and
# the gaming stack used by sashi-main.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sashi.desktop;

  gstPlugins = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];
in
{
  imports = [ ./ime.nix ];

  options.sashi.desktop = {
    gaming.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Steam and the AAGL anime-game launchers.  This also makes the
        aagl NixOS module's telemetry blocking active.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # qt6ct is configured (in ~/.config/qt6ct/qt6ct.conf) with
      # standard_dialogs=gtk3, so Qt file pickers are delegated to GTK3
      # through libqgtk3.so.  GTK3's file chooser needs
      # org.gtk.Settings.FileChooser, and NixOS relies on per-package
      # wrapping (wrapGAppsHook) to bake the schema dir into an app's env.
      # Derivations that only run wrapQtAppsHook (mkvtoolnix-gui) never pick
      # those schemas up, so overlay it to point XDG_DATA_DIRS at gtk3's
      # schema bundle.
      nixpkgs.overlays = [
        (
          final: prev:
          let
            withGtkSchemas =
              pkg:
              pkg.overrideAttrs (old: {
                qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [
                  "--prefix"
                  "XDG_DATA_DIRS"
                  ":"
                  "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}"
                ];
              });
          in
          {
            mkvtoolnix = withGtkSchemas prev.mkvtoolnix;
          }
        )
      ];

      # System side of Umbriel.  The NixOS module wires the session packages,
      # xdg-desktop-portal-umbriel, and xwayland-satellite.
      programs.umbriel.enable = true;

      # Noctalia Greeter renders its own wlroots compositor and lists the
      # installed Wayland sessions (including Umbriel).
      services.displayManager.noctalia-greeter = {
        enable = true;
        settings = {
          keyboard.layout = "us";
          session.default = "umbriel";
        };
      };

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;

        # Allow the graph to switch sample rate to match the source material /
        # connected hardware instead of always resampling to a fixed rate.
        # The range covers the FiiO BR15 R2R (up to 768 kHz/32-bit, incl. DSD)
        # and onboard/HDMI HDA audio (up to 192 kHz/24-bit).
        extraConfig.pipewire."10-clock-rates" = {
          "context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.allowed-rates" = [
              44100
              48000
              88200
              96000
              176400
              192000
              352800
              384000
              705600
              768000
            ];
          };
        };

        # Let PulseAudio-compat clients negotiate the same range instead of
        # being fixed at 48000 before reaching the graph.
        extraConfig.pipewire-pulse."10-clock-rates" = {
          "pulse.properties" = {
            "pulse.min.rate" = 44100;
            "pulse.max.rate" = 768000;
            "pulse.default.rate" = 48000;
            "pulse.allowed-rates" = [
              44100
              48000
              88200
              96000
              176400
              192000
              352800
              384000
              705600
              768000
            ];
          };
        };

        extraConfig.pipewire-pulse."11-resample-quality" = {
          "stream.properties" = {
            "resample.quality" = 15;
          };
        };

        extraConfig.client."10-resample-quality" = {
          "stream.properties" = {
            "resample.quality" = 15;
          };
        };
      };

      services.printing.enable = true;

      # Noctalia's battery and Bluetooth bar widgets need these services.
      # Bluetooth is harmless on machines without an adapter.
      services.upower.enable = true;
      hardware.bluetooth.enable = true;

      services.gvfs.enable = true;
      services.udisks2.enable = true;
      services.tumbler.enable = true;

      programs.dconf.enable = true;

      programs.firefox = {
        enable = true;
        preferences = {
          "media.ffmpeg.vaapi.enabled" = true;
          "media.hardware-video-decoding.force-enabled" = true;
        };
      };

      environment.systemPackages = gstPlugins;

      # Qt apps go through qt6ct so they pick up Noctalia/matugen colors.
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORMTHEME = "qt6ct";
        QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
        # Umbriel draws no server-side decorations; disable QtWayland's
        # client-side titlebar fallback to match GTK's ":" decoration layout.
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # Make the GStreamer plugins installed above discoverable by apps
        # that are not wrapped with a GST_PLUGIN_SYSTEM_PATH_1_0 of their own.
        GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPlugins;
      };
    }

    (lib.mkIf cfg.gaming.enable {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = false;
      };

      # Universal launcher plus the dedicated per-game launchers for titles
      # whose anime-games-launcher store entry is still a WIP stub.
      programs.anime-games-launcher.enable = true;
      programs.anime-game-launcher.enable = true;
      programs.honkers-launcher.enable = true;
      programs.honkers-railway-launcher.enable = true;
    })
  ];
}
