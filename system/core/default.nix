# System-wide policy that every host shares: Nix daemon settings, locale,
# the login user, security helpers, and the automatic remote-upgrade logic.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./auto-upgrade.nix
    ./gc.nix
    ./polkit.nix
    ./shred.nix
  ];

  # Accept the flake's declared substituters/keys (chaotic-nyx and aagl) when
  # root runs `nixos-rebuild` from the remote flake.  Without this, the local
  # rebuild would compile the kernel and gaming launchers from source even
  # though the caches are declared in flake.nix.
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "sashi"
    ];
    accept-flake-config = true;
  };

  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # Distrust the roots behind the compromised eMudhra intermediate CAs
  # (2026-10): emSign ECC Root CA - G3 and its Comodo AAA cross-sign.
  # Mozilla removed emSign ECC Root CA - G3 from certdata in NSS 3.131.1, and
  # buildcatrust aborts if a blacklist entry is missing, so only the Comodo
  # cross-sign remains listed here.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];

  users.users.sashi = {
    isNormalUser = true;
    description = "sashisashi569";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Lets non-NixOS binaries (e.g. AppImages bundling a .NET runtime) find
  # system libraries like libicu via a compatible dynamic linker.  Without
  # this, dotnet apps such as osu! fail with "Couldn't find a valid ICU
  # package installed on the system".  `fuse` (legacy 2.x, libfuse.so.2) is
  # needed for AppImages that Gear Lever integrates and launches directly
  # (bypassing appimage-run's FHS sandbox), which otherwise fail with
  # "AppImages require FUSE to run" / dlopen: libfuse.so.2 not found.
  environment.systemPackages = with pkgs; [
    fuse3
    # appimage-run sandboxes AppImages in its own bubblewrap FHS environment,
    # which shadows /lib64, /usr/lib etc. and ignores nix-ld entirely.  Missing
    # libraries (e.g. libicu, needed by .NET/Velopack apps like osu!) must be
    # added here via extraPkgs, not via programs.nix-ld.
    (appimage-run.override {
      extraPkgs = pkgs: [ pkgs.icu ];
    })
  ];

  services.pcscd.enable = true;

  # Graphical SSH passphrase prompts (SSH_ASKPASS): ssh-keygen -K (FIDO
  # resident keys), ssh-add, etc.  ksshaskpass is Qt/Wayland-native, so it
  # works under Umbriel without XWayland.  SSH_ASKPASS_REQUIRE makes OpenSSH
  # pick it over the controlling tty whenever WAYLAND_DISPLAY/DISPLAY is set,
  # while still falling back to the tty outside a graphical session.
  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

  # On-screen indicator for YubiKey touch requests.  Detects GPG/gpg-agent
  # (incl. SSH via enableSSHSupport) and U2F/WebAuthn, then signals through
  # libnotify and a unix socket at
  # $XDG_RUNTIME_DIR/yubikey-touch-detector.socket.
  programs.yubikey-touch-detector = {
    enable = true;
    libnotify = true;
    unixSocket = true;
  };

  environment.sessionVariables.SSH_ASKPASS_REQUIRE = "prefer";
}
