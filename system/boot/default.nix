# Bootloader and kernel policy shared by every host.
#
# The machine-specific parts (LUKS, filesystems, initrd modules, NIC quirks)
# live in hosts/<host>/hardware*.nix.  This module only owns the parts that
# should follow the dotfiles wherever they are installed.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sashi.boot;

  # chaotic-nyx's CachyOS kernel is built with linuxManualConfig from a fully
  # pre-resolved .config, so NixOS's usual boot.kernelPatches mechanism is a
  # no-op against it.  The supported override point is `cachyOverride`, which
  # re-runs chaotic-nyx's own config generation with a different cachyVars
  # set.  See the comment in the original hardware.nix for the full story.
  cachyPackages =
    if cfg.cachyos.nativeOptimization then
      pkgs.linuxPackages_cachyos-bore.cachyOverride {
        cachyVars = pkgs.linuxPackages_cachyos-bore.kernel.cachyConfig.cachyVars // {
          _processor_opt = "NATIVE";
        };
      }
    else
      pkgs.linuxPackages_cachyos-bore;
in
{
  options.sashi.boot = {
    cachyos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Use chaotic-nyx's CachyOS kernel with the BORE scheduler.
        '';
      };

      nativeOptimization = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Build the CachyOS kernel with `-march=native`.

          This disables binary-cache substitution for the kernel and makes the
          derivation depend on the CPU of the machine that builds it.  Keep it
          off when the remote GitHub Action is the source of truth: the CI
          build must produce the same kernel derivation that the host installs.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      # Lanzaboote installs its own signed systemd-boot and Unified Kernel
      # Images.  The stock systemd-boot module must be disabled even though
      # both use the same underlying bootloader files.
      boot.loader.systemd-boot.enable = lib.mkForce false;

      # Lanzaboote reads/writes the EFI variables when enrolling keys.
      boot.loader.efi.canTouchEfiVariables = true;

      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";

        # The ESP is 1 GiB and shared with Windows.  On sashi-main a kernel is
        # ~19 MiB and the initrd ~28 MiB, so each retained generation costs
        # roughly 47 MiB.  Ten generations (~470 MiB) leave room for Windows,
        # systemd-boot, fwupd capsules, and the temporary overlap when
        # Lanzaboote replaces systemd-boot.  See docs/secureboot.md before
        # raising this.
        configurationLimit = 10;
      };

      # Kernel command-line editing would let anyone with physical access add
      # init=/bin/sh and bypass the LUKS login.  This is independent of Secure
      # Boot but belongs with it.
      boot.loader.systemd-boot.editor = false;

      # Key generation, enrollment, and verification are deliberately manual;
      # see docs/secureboot.md.
      environment.systemPackages = [ pkgs.sbctl ];
    }

    (lib.mkIf cfg.cachyos.enable {
      boot.kernelPackages = cachyPackages;

      # cachyos-bore builds BBR3 as a module but defaults to cubic.  Load it
      # and select it explicitly.
      boot.kernelModules = [ "tcp_bbr3" ];
      boot.kernel.sysctl."net.ipv4.tcp_congestion_control" = "bbr3";

      # Linux 7.2 no longer emits per-module `.cer` files (and therefore no
      # aggregate `modules.cer`), but nixpkgs' kernel module aggregator still
      # tries to merge them unconditionally.  Skip that merge when the kernel
      # provides no aggregate; runtime signature verification uses the key
      # built into the kernel, not this file.
      nixpkgs.overlays = [
        (final: prev: {
          aggregateModules =
            modules:
            (prev.aggregateModules modules).overrideAttrs (_: {
              postBuild = ''
                source ${prev.stdenvNoCC}/setup

                if ! test -d "$out/lib/modules"; then
                  echo "No modules found."
                  # To support a kernel without modules
                  exit 0
                fi

                kernelVersion=$(cd $out/lib/modules && ls -d *)
                if test "$(echo $kernelVersion | wc -w)" != "1"; then
                  echo "inconsistent kernel versions: $kernelVersion"
                  exit 1
                fi

                echo "kernel version is $kernelVersion"

                shopt -s extglob

                # Regenerate the depmod map files.  Be sure to pass an explicit
                # kernel version number, otherwise depmod will use `uname -r`.
                if test -w $out/lib/modules/$kernelVersion; then
                  rm -f $out/lib/modules/$kernelVersion/modules.!(builtin*|order*|cer)
                  ${prev.kmod}/bin/depmod -b $out -C $out/etc/depmod.d -a $kernelVersion
                  cd -- "$out/lib/modules/$kernelVersion"

                  # Merge the single-module certificates for external modules.
                  if [ -e modules.cer ]; then
                    cp --no-preserve=mode,ownership --remove-destination \
                      -- "$(readlink -f modules.cer)" modules.cer
                    sed "1,$(wc -l < modules.order)d; s/\.ko.*/.ko.cer/" modules.dep \
                      | xargs -d'\n' cat >> modules.cer
                  fi
                fi
              '';
            });
        })
      ];
    })
  ];
}
