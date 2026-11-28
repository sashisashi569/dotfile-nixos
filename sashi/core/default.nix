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
  home.username = "sashi";
  home.homeDirectory = "/home/sashi";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    keepassxc
    yubioath-flutter
    monophony
    recordbox
    mpv
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
    rclone
    thunderbird
    tor-browser
    uv
    nodejs_22 # npx: opencode MCP servers
    opencode
    usbimager

    arduino-ide

    # File manager and image viewer
    nautilus
    eog
    ffmpegthumbnailer
    gvfs
    gnome-disk-utility # mount .iso/.img from Nautilus

    # Wayland utilities: kitty is the terminal, wl-clipboard backs shell
    # scripts.  Screenshots go through Noctalia's built-in capture.
    wl-clipboard
    kitty

    # Terminal font.  JetBrains Mono has stronger stems and better hinting
    # than fontconfig's default DejaVu Sans Mono at terminal sizes.
    jetbrains-mono

    # Let Qt apps pick up Noctalia/matugen-generated colors
    # (QT_QPA_PLATFORMTHEME is set by the system desktop module).
    qt6Packages.qt6ct
    libsForQt5.qt5ct
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

  # Kitty has no config by default, so it uses DejaVu Sans Mono at 11pt.
  # That looks soft on the 27" 2560x1440 panel.  Use JetBrains Mono with
  # explicit Japanese fallback, a slightly larger size, and a little extra
  # glyph contrast for light text on the dark background.  Monitor scale is
  # 1.0 on every output; kitty computes DPI itself, so no fractional scaling
  # is involved here.
  xdg.configFile."kitty/kitty.conf".text = ''
    font_family JetBrains Mono
    # kitty renders at 96 DPI here, so 12pt is exactly 16px (integer pixels
    # keep FreeType hinting crisp); 12.5pt would land on 16.67px.
    font_size 12

    # Keep Japanese in the Japanese variant; fontconfig otherwise falls back
    # to Noto Sans Mono CJK KR for these ranges.
    symbol_map U+3000-U+30FF,U+31F0-U+31FF,U+3200-U+33FF,U+3400-U+4DBF,U+4E00-U+9FFF,U+F900-U+FAFF,U+FE10-U+FE1F,U+FE30-U+FE4F,U+FF00-U+FFEF Noto Sans Mono CJK JP

    # Linux default is "1.0 0"; a little contrast makes glyphs less washed out.
    text_composition_strategy 1.0 20
  '';

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
