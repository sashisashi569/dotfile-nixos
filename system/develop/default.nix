# Development/compute support shared by both hosts.  The desktop and the
# laptop are both development machines; virtualisation is opt-in because only
# sashi-main acts as the compute host.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sashi.develop;
in
{
  options.sashi.develop.virtualisation.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable libvirt/QEMU, virt-manager and PCI/USB passthrough helpers.
    '';
  };

  config = lib.mkMerge [
    {
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          icu
          openssl
          zlib
          curl
          libunwind
          fuse
        ];
      };

      environment.systemPackages = with pkgs; [
        git
        openssh
        vim-full # gvim を含む (GUI 有効 vim ビルド)

        # Small native-development baseline (the language toolchains are
        # installed per user in sashi/core).
        gcc
        gnumake
        pkg-config
        file
        jq
        ripgrep
        fd
        unzip
        zip
      ];
    }

    (lib.mkIf cfg.virtualisation.enable {
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          # UEFI images (needed for e.g. Windows 11 / Secure Boot ISOs) are
          # bundled with qemu itself; no separate ovmf.enable option.
          swtpm.enable = true;
          # Registers virtiofsd's vhost-user descriptor so libvirt can find it
          # when a domain uses a virtiofs filesystem device.
          vhostUserPackages = [ pkgs.virtiofsd ];
        };
      };

      # Let libvirt guests on the default NAT network reach TCP/5000 on the
      # host.
      networking.firewall.interfaces."virbr0".allowedTCPPorts = [ 5000 ];

      # USB device redirection into guests from the virt-viewer/virt-manager
      # UI.
      virtualisation.spiceUSBRedirection.enable = true;

      programs.virt-manager.enable = true;

      # virt-manager needs dconf to persist its UI state (window size, last
      # connection, ...) between launches.
      programs.dconf.enable = true;

      users.users.sashi.extraGroups = [ "libvirtd" ];
    })
  ];
}
