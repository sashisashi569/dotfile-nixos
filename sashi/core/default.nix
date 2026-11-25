# Shared home-manager configuration for both hosts.
#
# Host-specific Umbriel/Noctalia settings are imported by hosts/<host>/home.nix;
# gaming packages are in ../../sashi/gaming.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./aria2.nix
    ./torrent.nix
  ];

  home.username = "sashi";
  home.homeDirectory = "/home/sashi";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    keepassxc
    yubioath-flutter
    monophony
    celluloid
    libdvdcss
    picard
    mkvtoolnix # mkvmerge

    # Bit-perfect CD ripper feeding into a manual MusicBrainz Picard
    # workflow: whipper should only ever write CD-native data (TOC/DiscID,
    # AccurateRip-verified raw audio, and a full rip log) and must never
    # auto-tag from an online match.  Wrapped so `whipper cd rip` always lands
    # in raw-ripped with -U set; every other subcommand passes through.
    (pkgs.writeShellApplication {
      name = "whipper";
      text = ''
        real_whipper="${pkgs.whipper}/bin/whipper"
        if [ $# -ge 2 ] && [ "$1" = "cd" ] && [ "$2" = "rip" ]; then
          shift 2
          exec "$real_whipper" cd rip -O "$HOME/音楽/raw-ripped" "$@"
        fi
        exec "$real_whipper" "$@"
      '';
    })
    mpd
    euphonica
    (pkgs.callPackage ../../packages/rename-music-by-tags { })
    rclone
    thunderbird
    tor-browser
    uv
    nodejs_22 # npx: opencode MCP servers (e.g. mcp-searxng)
    opencode
    usbimager
    megasync

    arduino-ide

    # file manager
    nautilus
    ffmpegthumbnailer
    gvfs
    gnome-disk-utility # mount .iso/.img from Nautilus

    # Wayland utilities: foot is the terminal, wl-clipboard backs shell
    # scripts.  Screenshots go through Noctalia's built-in capture.
    wl-clipboard
    foot

    # Let Qt apps pick up Noctalia/matugen-generated colors
    # (QT_QPA_PLATFORMTHEME is set by the system desktop module).
    qt6Packages.qt6ct
    libsForQt5.qt5ct

    # Peergos' Flatpak calls the host zenity for its folder picker.
    zenity
  ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    package = pkgs.noctalia;
    # `settings` is set by each host's home.nix so monitor/wallpaper choices
    # stay host-specific.
  };

  # The Noctalia Settings UI persists changes to
  # ~/.local/state/noctalia/settings.toml, which overrides the declarative
  # ~/.config/noctalia/config.toml.  Remove the override on activation so the
  # flake remains the source of truth.
  home.activation.removeNoctaliaStateOverride = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/rm -f "${config.home.homeDirectory}/.local/state/noctalia/settings.toml"
  '';

  # The default remote list is replaced by any explicit definition, so merge
  # the Peergos repo into it rather than dropping Flathub.
  services.flatpak.remotes = lib.mkOptionDefault [
    {
      name = "peergos";
      location = "https://flatpak.peergos.org/peergos.flatpakrepo";
    }
  ];

  services.flatpak.packages = [
    {
      appId = "ca.edestcroix.Recordbox";
      origin = "flathub";
    }
    {
      appId = "org.peergos.Peergos";
      origin = "peergos";
    }
    # Chromium's proprietary codec extension: without it Peergos can't play
    # H.264/MP4 videos.  VP9/WebM work regardless.
    {
      appId = "org.chromium.Chromium.Codecs";
      origin = "flathub";
    }
  ];

  # WebAuthn security keys need raw USB device access from inside the
  # sandbox (`flatpak override --user --device=all org.peergos.Peergos`).
  services.flatpak.overrides.settings."org.peergos.Peergos".Context.devices = [ "all" ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Tor Browser ships its own .desktop into the home-manager profile
      # (which precedes the system profile on XDG_DATA_DIRS), so without
      # explicit entries `xdg-settings get default-web-browser` resolves to
      # tor-browser.desktop.  Pin Firefox (enabled system-wide) instead.
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";

      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/x-cd-image" = "gnome-disk-image-mounter.desktop";
      "application/x-raw-disk-image" = "gnome-disk-image-mounter.desktop";
    };
  };

  xdg.configFile."mimeapps.list".force = true;

  # rclone connection strings misparse URLs containing "://" and port ":N",
  # so configure the WebDAV remote in a proper config file instead.  This
  # file is kept separate from the default rclone.conf (and passed via
  # --config below) because home-manager owns it as a read-only store
  # symlink: sharing it would stop `rclone config` from saving remotes the
  # user adds interactively.
  home.file.".config/rclone/taildrive.conf".text = ''
    [taildrive]
    type = webdav
    url = http://100.100.100.100:8080
    vendor = other
  '';

  # Remote `pacikaconwa` is created interactively with `rclone config` into
  # the default rclone.conf; this unit only mounts it once that entry exists.
  systemd.user.services.keepass = {
    Unit = {
      Description = "Mount pacikaconwa WebDAV via rclone";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/keepass";
      # The WebDAV remote disables DELETE, so a server-side rename that
      # overwrites (KeePassXC's atomic save via QSaveFile) fails under
      # `--vfs-cache-mode off`.  `writes` keeps that create+rename pair in
      # the local VFS cache and uploads the result with a plain PUT
      # overwrite; the cache is on tmpfs so decrypted database content is
      # never written to disk.
      ExecStart = "${pkgs.rclone}/bin/rclone mount pacikaconwa: %h/keepass --vfs-cache-mode writes --cache-dir /dev/shm/rclone --no-modtime --allow-non-empty";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/keepass";
      Restart = "on-failure";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.taildrive = {
    Unit = {
      Description = "Mount Tailscale Taildrive via WebDAV";
      After = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'mkdir -p %h/Taildrive'"
        "${pkgs.bash}/bin/bash -c 'until /run/current-system/sw/bin/tailscale status > /dev/null 2>&1; do sleep 2; done'"
      ];
      ExecStart = "${pkgs.rclone}/bin/rclone mount taildrive: %h/Taildrive --config %h/.config/rclone/taildrive.conf --vfs-cache-mode writes --no-modtime --allow-non-empty";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/Taildrive";
      Restart = "on-failure";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Hand-rolled instead of services.mpd: that module always writes a
  # playlist_directory line (and mkdir's it), but we want playlist
  # save/load left disabled entirely rather than pointed at an unused
  # folder.  Output is PipeWire-only with no "format" pinned and the
  # resampler set to the cheap "internal" plugin, so MPD passes audio
  # through untouched and PipeWire's graph does any rate conversion.
  xdg.configFile."mpd/mpd.conf".text = ''
    music_directory  "${config.home.homeDirectory}/Nextcloud/Music"
    db_file          "${config.xdg.dataHome}/mpd/tag_cache"
    state_file       "${config.xdg.dataHome}/mpd/state"
    sticker_file     "${config.xdg.dataHome}/mpd/sticker.sql"
    bind_to_address  "127.0.0.1"

    resampler {
        plugin "internal"
    }

    audio_output {
        type "pipewire"
        name "PipeWire"
    }
  '';

  systemd.user.services.mpd = {
    Unit = {
      Description = "Music Player Daemon";
      After = [ "pipewire.service" ];
    };
    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/share/mpd";
      ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon %h/.config/mpd/mpd.conf";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Qogir-dark";
      package = pkgs.qogir-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig.gtk-decoration-layout = ":";
    gtk4.extraConfig.gtk-decoration-layout = ":";

    # gtk.css itself is left to Noctalia's matugen-driven app-theming
    # template, which writes it directly.  home-manager only owns the
    # settings above, not the generated CSS files.
  };

  # Umbriel runs no XSettings daemon to publish gtk-decoration-layout, so
  # GTK's headerbar falls back to this GSettings key instead.
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = false;
  };

  programs.home-manager.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
      "github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentitiesOnly = true;
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "sashisashi569";
        email = "83458880+sashisashi569@users.noreply.github.com";
      };
      # gh's credential helper is added by programs.gh.
      am.threeWay = true;
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "vim";
    };
  };
}
