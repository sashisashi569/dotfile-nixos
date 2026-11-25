# A disk-backed scratch directory plus the XDG trash that are securely wiped
# (GNU shred) both at boot and on shutdown/reboot: files stay usable for the
# whole session, the content is overwritten before the machine powers off, and
# anything left over by a crash or a forced power-off is wiped before the next
# session starts.
#
# The root filesystem is ext4 on LUKS, so overwriting file content in place is
# meaningful here. On a CoW filesystem (btrfs) or on data that is already
# covered by full-disk encryption, the overwrite would not reach the original
# blocks, but removing the files still happens.
{ lib, pkgs, ... }:

let
  home = "/home/sashi";
  scratch = "${home}/shred";

  # Wipe the contents of these directories, but keep the directories themselves
  # so the desktop (gio) can keep writing into the trash.
  targets = [
    scratch
    "${home}/.local/share/Trash/files"
    "${home}/.local/share/Trash/info"
    "${home}/.local/share/Trash/expunged"
  ];

  wipe = pkgs.writeShellScript "shred-scratch" ''
    set -eu

    # Overwrite regular files in place, then unlink them. Everything else
    # (directories, symlinks, sockets, ...) has no file content of its own, so
    # deleting it is sufficient.
    wipe_dir() {
      dir=$1
      [ -d "$dir" ] || return 0
      ${pkgs.findutils}/bin/find "$dir" -mindepth 1 -type f -print0 \
        | ${pkgs.findutils}/bin/xargs -0 -r ${pkgs.coreutils}/bin/shred --force --remove --
      ${pkgs.findutils}/bin/find "$dir" -mindepth 1 -delete
    }

    for dir in ${lib.escapeShellArgs targets}; do
      wipe_dir "$dir"
    done
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${scratch} 0700 sashi users -"
  ];

  # Safety net for a crash or a forced power-off, where the shutdown wipe never
  # ran: clean up before the session starts.
  systemd.services.shred-scratch-boot = {
    description = "Securely wipe ${scratch} and the trash (leftovers from a previous run)";
    wantedBy = [ "multi-user.target" ];
    before = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = home;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = wipe;
      RemainAfterExit = true;
      # Never abort in the middle of a wipe; a partial overwrite leaves data.
      TimeoutStartSec = "0";
    };
  };

  # Pulled in by shutdown.target, so the wipe runs on poweroff, reboot and
  # halt while the filesystem is still mounted and writable.
  systemd.services.shred-scratch-shutdown = {
    description = "Securely wipe ${scratch} and the trash";
    wantedBy = [ "shutdown.target" ];
    before = [
      "shutdown.target"
      "umount.target"
    ];
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = home;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = wipe;
      # Never abort in the middle of a wipe; a partial overwrite leaves data.
      TimeoutStartSec = "0";
    };
  };
}
