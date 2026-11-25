# Remote-as-truth automatic upgrade.
#
# GitHub Actions updates flake.lock and builds both hosts; only a successful
# build is committed.  On the machine, two timers cooperate:
#
#   * every week at 22:00, `nixos-rebuild boot --refresh` installs the next
#     boot generation from the remote flake;
#   * ten minutes after boot, a catch-up check runs the same rebuild only if
#     the most recent weekly slot was missed (machine powered off).
#
# `nixos-rebuild boot` is intentional: the running system is untouched and the
# new generation is selected on the next reboot.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.sashi.autoUpgrade;

  stateDir = "/var/lib/nixos-auto-upgrade";
  nixosRebuild = "${config.system.build.nixos-rebuild}/bin/nixos-rebuild";
  flakeRef = "${cfg.flake}#${cfg.hostname}";

  upgradeScript = pkgs.writeShellScript "nixos-remote-upgrade" ''
    set -eu
    umask 022

    # Serialise the weekly run and the boot catch-up run.
    exec 9>"${stateDir}/lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "nixos-remote-upgrade: another instance is already running" >&2
      exit 0
    fi

    ${pkgs.coreutils}/bin/date +%s > "${stateDir}/last-attempt"

    echo "nixos-remote-upgrade: fetching and building ${flakeRef}"
    ${nixosRebuild} boot --refresh --accept-flake-config --flake ${lib.escapeShellArg flakeRef}

    ${pkgs.coreutils}/bin/date +%s > "${stateDir}/last-success"
    echo "nixos-remote-upgrade: boot generation updated; reboot to activate"
  '';

  # GNU date computes the most recent occurrence of the weekly schedule.
  # `this <day> <time>` is in the past when the current slot has already
  # passed (including "today after 22:00"), otherwise it is next week's slot.
  catchUpScript = pkgs.writeShellScript "nixos-remote-upgrade-catchup" ''
    set -eu

    last_success=0
    if [ -r "${stateDir}/last-success" ]; then
      last_success=$(${pkgs.coreutils}/bin/cat "${stateDir}/last-success")
    fi

    now=$(${pkgs.coreutils}/bin/date +%s)
    this_slot=$(${pkgs.coreutils}/bin/date -d "this ${cfg.dayOfWeek} ${cfg.time}" +%s)
    if [ "$this_slot" -le "$now" ]; then
      due=$this_slot
    else
      due=$((this_slot - 7 * 24 * 60 * 60))
    fi

    if [ "$last_success" -ge "$due" ]; then
      echo "nixos-remote-upgrade-catchup: no missed run (last success: $(${pkgs.coreutils}/bin/date -d "@$last_success" 2>/dev/null || echo never))"
      exit 0
    fi

    echo "nixos-remote-upgrade-catchup: weekly run at $(${pkgs.coreutils}/bin/date -d "@$due") was missed; starting now"
    ${config.systemd.package}/bin/systemctl start --no-block nixos-remote-upgrade.service
  '';
in
{
  options.sashi.autoUpgrade = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the weekly remote rebuild timer and its boot catch-up timer.
      '';
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:sashisashi569/dotfile-nixos";
      example = "github:sashisashi569/dotfile-nixos";
      description = ''
        Flake URI that is treated as the source of truth.  The host name is
        appended as `#<hostname>`.  GitHub Actions pushes flake.lock here after
        a successful build of every host.
      '';
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "NixOS configuration attribute to rebuild.";
    };

    dayOfWeek = lib.mkOption {
      type = lib.types.str;
      default = "Mon";
      example = "Sun";
      description = ''
        Weekday of the local rebuild.  `date -d "this <day> <time>"` must accept
        the value, so use the English three-letter form.
      '';
    };

    time = lib.mkOption {
      type = lib.types.str;
      default = "22:00";
      example = "22:00";
      description = "Local time (HH:MM) of the weekly rebuild.";
    };

    bootDelay = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = ''
        Delay after boot before checking whether the last weekly slot was
        missed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixos-remote-upgrade = {
      description = "Build the next NixOS boot generation from the remote flake";

      environment =
        config.nix.envVars
        // {
          HOME = "/root";
        }
        // config.networking.proxy.envVars;

      path = with pkgs; [
        coreutils
        gnutar
        xz.bin
        gzip
        gitMinimal
        config.nix.package.out
        config.programs.ssh.package
        util-linux
      ];

      # network-online.target is ordered before the timer-requested service;
      # a failed fetch leaves the current generation untouched.
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "nixos-auto-upgrade";
        ExecStart = upgradeScript;
        Nice = 10;
        IOSchedulingClass = "idle";
        # Kernel/toolchain builds can legitimately take a long time.
        TimeoutStartSec = "0";
      };
    };

    systemd.timers.nixos-remote-upgrade = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "${cfg.dayOfWeek} ${cfg.time}";
        AccuracySec = "1min";
        # Do not let systemd replay a missed calendar tick immediately at
        # boot; nixos-remote-upgrade-catchup owns that path so the rebuild is
        # delayed by bootDelay instead.
        Persistent = false;
        Unit = "nixos-remote-upgrade.service";
      };
    };

    systemd.services.nixos-remote-upgrade-catchup = {
      description = "Catch up a missed weekly NixOS remote rebuild";

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path = with pkgs; [
        coreutils
        systemd
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = catchUpScript;
      };
    };

    systemd.timers.nixos-remote-upgrade-catchup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.bootDelay;
        Unit = "nixos-remote-upgrade-catchup.service";
      };
    };
  };
}
