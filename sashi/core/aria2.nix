# aria2 on the noctalia-testing branch: the RPC daemon (systemd user unit) plus
# a small StatusNotifierItem tray controller for it. The tray itself is a
# Python script (aria2-tray.py) wired up below; Umbriel launches it via the
# `[general] autostart` entry in umbriel.nix, so it is intentionally not a
# systemd unit.
{ pkgs, config, ... }:

let
  # aria2p talks JSON-RPC to the daemon; pystray provides the tray icon (its
  # appindicator backend is what shows up as a StatusNotifierItem on Wayland);
  # Pillow draws the icon.
  python = pkgs.python3.withPackages (
    ps: with ps; [
      aria2p
      pystray
      pillow
    ]
  );

  # wrapGAppsHook3 collects the GI_TYPELIB_PATH / GSETTINGS_SCHEMA_DIR entries
  # from the whole closure (gtk3 and libayatana-appindicator are propagated by
  # pystray), which is what lets pystray's appindicator backend import
  # gi.repository on Wayland. LD_LIBRARY_PATH is added explicitly because
  # GIRepository dlopens the indicator library and the wrapper script is not an
  # ELF binary carrying an RPATH.
  aria2-tray = pkgs.stdenv.mkDerivation {
    pname = "aria2-tray";
    version = "0-unstable";

    dontUnpack = true;

    nativeBuildInputs = [
      pkgs.wrapGAppsHook3
      pkgs.gobject-introspection
    ];

    buildInputs = [
      python
      pkgs.gtk3
      pkgs.libayatana-appindicator
      pkgs.gsettings-desktop-schemas
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cat > $out/bin/aria2-tray <<'EOF'
      #!${pkgs.runtimeShell}
      exec ${python}/bin/python3 ${./aria2-tray.py} "$@"
      EOF
      chmod +x $out/bin/aria2-tray
      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(
        --prefix LD_LIBRARY_PATH : "${
          pkgs.lib.makeLibraryPath [
            pkgs.gtk3
            pkgs.libayatana-appindicator
          ]
        }"
      )
    '';

    meta = {
      description = "System tray controller for the local aria2c RPC daemon";
      mainProgram = "aria2-tray";
      platforms = pkgs.lib.platforms.linux;
    };
  };
in
{
  home.packages = [ aria2-tray ];

  # aria2c を RPC デーモンとして常駐させ、トレイ (aria2-tray) から操作する。
  # --enable-rpc はモジュール側の ExecStart に付与され、設定は次の settings を
  # 経由して ~/.config/aria2/aria2.conf に書き出される。
  programs.aria2 = {
    enable = true;
    systemd.enable = true;
    settings = {
      dir = "${config.home.homeDirectory}/Downloads";
      rpc-listen-all = false;
    };
  };
}
