# UEFI Secure Boot with Lanzaboote

This repository enables [Lanzaboote](https://github.com/nix-community/lanzaboote)
for both hosts.  Lanzaboote replaces the stock systemd-boot installation with
signed systemd-boot binaries and signed Unified Kernel Images (UKIs).

The flake pins the stable `v1.2.0` release (not `master`).  Key generation and
enrollment are intentionally **manual**: `autoGenerateKeys` and
`autoEnrollKeys` are not used, because enrollment changes firmware state and
must be reviewed together with Windows dual boot, BitLocker, and option ROMs.
This change does not enable Lanzaboote measured boot or TPM2-bound LUKS; it only
adds Secure Boot signing and the manual key-enrollment workflow.

Relevant configuration lives in `system/boot/default.nix`:

```nix
boot.loader.systemd-boot.enable = lib.mkForce false;
boot.loader.efi.canTouchEfiVariables = true;

boot.lanzaboote = {
  enable = true;
  pkiBundle = "/var/lib/sbctl";
  configurationLimit = 10;
};

boot.loader.systemd-boot.editor = false;
environment.systemPackages = [ pkgs.sbctl ];
```

`configurationLimit = 10` is chosen for the 1 GiB ESP.  On sashi-main the
current kernel is about 19 MiB and the initrd about 28 MiB, so one Lanzaboote
generation costs roughly 47 MiB on the ESP.  Ten generations are about 470 MiB,
leaving room for Windows Boot Manager, systemd-boot, fwupd capsules, and the
temporary overlap while replacing systemd-boot.  At the time of writing the ESP
had 278 MiB used and 745 MiB free, with two system generations.  Do not raise
this limit without checking `df -h /boot`; if space is tight, lower it to 5–8.

## Before you start

- Verify that the machine really boots in UEFI mode (`bootctl status`), that
  `/boot` is the ESP, and that Secure Boot is currently **disabled or in setup
  mode**.  sashi-main is in setup mode today.
- Update the firmware first.  A firmware update is much easier before custom
  keys are enrolled.
- Set a firmware/BIOS password.  Secure Boot is not meaningful if anyone can
  walk up to the machine and disable it.
- If Windows uses BitLocker, export and verify the BitLocker recovery key.
  Enrolling Secure Boot keys changes PCR 7 and may cause BitLocker to ask for
  recovery on the next Windows boot.  Keeping a Windows recovery medium is also
  recommended.
- Back up the ESP before the first migration, for example with
  `sudo tar -C / -czf /var/tmp/boot-before-lanzaboote.tar.gz boot`.
- Do not commit `/var/lib/sbctl` or its backups to this repository.  It contains
  the private platform key.
- The weekly `nixos-remote-upgrade` timer also runs `nixos-rebuild boot` as
  root.  If it fires after this configuration is deployed but before
  `sbctl create-keys`, its activation will fail because Lanzaboote cannot sign
  the new generation (the current boot generation remains intact).  Create the
  keys first, or temporarily disable `sashi.autoUpgrade.enable` / the timer
  until the manual steps below are complete.

`nixos-rebuild build` does not need the keys: only the boot/switch activation
runs the Lanzaboote install hook that signs and writes to the ESP.

### sashi-letsnote is a placeholder

`hosts/sashi-letsnote/hardware-configuration.nix` is still the CI placeholder,
although it declares `/boot` as a vfat ESP.  Lanzaboote is enabled for that host
so both configurations are evaluated and built, but do **not** create keys or
enroll them on the real laptop until the generated hardware configuration has
been installed and the laptop is confirmed to be UEFI with `/boot` as its ESP.
If the real laptop is legacy BIOS or uses a different boot layout, do not deploy
this boot module there until the configuration is adapted.

## One-time enrollment, in this order

Run these steps on the machine itself.  Do not enroll keys before the signed
Lanzaboote bootloader is installed.

### 1. Create the custom keys

`sbctl` is added to the system by this configuration, so it is not necessarily
in `PATH` on the running generation yet.  Run the pinned flake package
explicitly:

```console
SBCTL=$(nix build --no-link --print-out-paths .#nixosConfigurations.sashi-main.pkgs.sbctl)
sudo "$SBCTL/bin/sbctl" create-keys
sudo "$SBCTL/bin/sbctl" status
```

This creates `/var/lib/sbctl` with a custom PK, KEK, and db.  It does **not**
enroll them yet.  If keys already exist, do not overwrite them; inspect
`sbctl status` and restore the backup if necessary.  After the first reboot
into the Lanzaboote generation, plain `sudo sbctl ...` works.

### 2. Install the signed Lanzaboote bootloader

Still with Secure Boot disabled/setup mode:

```console
pkexec ./rebuild.sh boot
# or: sudo nixos-rebuild boot --flake .#sashi-main
```

This signs systemd-boot, the kernel/UKI stubs, and installs them on the ESP.
It does not enroll keys.  `nixos-rebuild boot` is deliberate: the running
system is untouched and the new generation is selected on the next reboot.

### 3. Reboot before enforcing

```console
df -h /boot
sudo reboot
```

Optionally check the signatures before rebooting with the same `$SBCTL` path
used above: `sudo "$SBCTL/bin/sbctl" verify`.

Reboot **while Secure Boot is still disabled/setup mode** and confirm that the
Lanzaboote menu appears and NixOS boots normally.  This validates the signed
loader before the firmware starts enforcing signatures.

### 4. Enroll the custom keys plus Microsoft keys

After the successful test boot:

```console
bootctl status          # expect "Secure Boot: disabled (setup)"
sudo sbctl verify
sudo sbctl enroll-keys --microsoft
```

`sbctl verify` should show the signed systemd-boot and
`EFI/Linux/nixos-generation-*.efi` files.  It may also print raw kernel/initrd
files or old entry files as unsigned/not PE; those are not the signed boot
chain.  Look for `✓` on `EFI/systemd/systemd-bootx64.efi` and the generation
UKIs.

`--microsoft` adds Microsoft's KEK/db certificates.  This is required for the
Microsoft-signed Windows Boot Manager and for option ROMs signed with the
Microsoft UEFI CA.  Using only the custom key would make Windows and some
graphics/network cards unbootable.

### 5. Reboot and verify enforcement

```console
sudo reboot
bootctl status
sudo sbctl verify
```

`bootctl status` should now report `Secure Boot: enabled (user)` after the
firmware has been switched on.  On some AMI boards enrolling the PK leaves
Secure Boot disabled until you enter firmware setup and enable it (often under
"OS Type: Windows UEFI Mode").  If so, enable it there and reboot.

Finally, confirm that the Windows Boot Manager still appears in the boot menu
and that Windows starts.  If BitLocker asks for recovery, enter the exported
recovery key, then re-enable BitLocker protection from Windows.

### Why keys must not be enrolled first

The existing NixOS systemd-boot binary is not signed with your new key.  If the
custom PK/KEK/db are enrolled first and the firmware is in user mode (or Secure
Boot is enabled), the firmware will refuse to load the old bootloader and the
machine will not boot Linux.  Installing signed Lanzaboote first, then
enrolling keys while still in setup mode, keeps a working signed loader on the
ESP throughout the transition.

If the machine is already unbootable because keys were enrolled too early,
disable Secure Boot or reset the firmware to setup mode, boot the signed
Lanzaboote generation (or a recovery medium), and redo the order above.

## Optional: firmware-builtin keys

Some vendors (notably Framework) require the firmware's pre-provisioned OEM
certificates to remain trusted for vendor firmware updates.  If a firmware or
hardware component refuses to work, enroll with:

```console
sudo sbctl enroll-keys --microsoft --firmware-builtin
```

`--firmware-builtin` keeps the vendor keys that are already in the firmware in
addition to your custom key and the Microsoft keys.  The tradeoff is that any
binary signed by those vendor keys is also trusted, which widens the attack
surface; use it only when the hardware actually requires it.  A later
`enroll-keys` without the flag replaces the key set and removes those vendor
keys again.

`--tpm-eventlog` is another experimental option that records checksums of
option ROMs seen in the last boot.  It is brittle across firmware/GPU updates
and is not recommended as a default.  Do not use
`--yes-this-might-brick-my-machine`.

## Windows dual boot and option ROMs

- Windows Boot Manager lives on the same ESP and is Microsoft-signed.  The
  `--microsoft` enrollment above is what keeps it bootable.  Keep the Windows
  recovery key and installation media available.
- A major Windows update or firmware update can update the Secure Boot dbx or
  replace `bootmgfw.efi`.  If Windows stops booting after such an update, use
  the firmware boot menu to select Windows directly, then re-check
  `bootctl status` and `sbctl status`.  As a last resort, disable Secure Boot in
  firmware setup and re-enroll the keys after repairing Windows.
- Many GPU/network option ROMs are signed by the Microsoft UEFI CA, so
  `--microsoft` is normally sufficient.  If a card's option ROM uses a
  different vendor certificate, the firmware may stop at a security violation.
  Try `--firmware-builtin` only if that vendor key is actually present, or
  update the card/firmware.  `--tpm-eventlog` is the experimental fallback.
- Lanzaboote's systemd-boot scans for Windows Boot Manager automatically, but
  the NixOS entries use the Lanzaboote sort key and remain the default.

### Old systemd-boot entries

After the first successful Lanzaboote boot, the old systemd-boot menu entries
can remain under `/boot/loader/entries` and show up as broken duplicates.  Once
you have confirmed the new entries boot, move them aside (do not delete the
Lanzaboote UKIs in `/boot/EFI/Linux`):

```console
sudo mkdir -p /boot/loader/entries.systemd-boot.bak
sudo mv /boot/loader/entries/nixos-generation-*.conf /boot/loader/entries.systemd-boot.bak/
```

Lanzaboote manages its UKIs directly and does not need these `.conf` files.

## Recovery

### If Linux does not boot

1. Enter firmware setup (usually Del/F2), disable Secure Boot, and/or use the
   "Reset to Setup Mode" option.  Boot the previous Lanzaboote generation or a
   NixOS installer.
2. If a generation boots, run `nixos-rebuild boot` again with the same flake.
   Lanzaboote will re-sign and reinstall the missing artifacts.
3. If no generation boots, boot an unsigned NixOS installer with Secure Boot
   disabled, mount the root and ESP as for installation, `nixos-enter`, and run
   `nixos-rebuild boot`.  If the ESP is corrupted, `fsck.fat` it first and only
   reformat if it cannot be mounted.

### If the keys are lost

Restore `/var/lib/sbctl` from the offline backup before rebuilding, or create a
new key set with `sbctl create-keys` and enroll it from firmware setup mode.
A new key cannot replace an already-enrolled PK unless the firmware is in setup
mode.  This is why the key backup matters: losing the private key means losing
the ability to sign future kernels until the firmware policy is reset.

### Do not use "Clear All Secure Boot Keys" casually

That firmware option can drop the Forbidden Signature Database (dbx) as well as
the enrolled keys.  Losing dbx weakens protection against known-bad bootloaders.
Prefer "Reset to Setup Mode" or deleting only the PK, and re-check dbx afterward
with:

```console
ls -l /sys/firmware/efi/efivars/dbx-*
```

### If the ESP fills up

Lanzaboote's installer fails with "No space left on device" when the ESP cannot
hold another kernel/initrd.  Lower `boot.lanzaboote.configurationLimit` (for
example to 5), run `nix-collect-garbage --delete-older-than 7d` if appropriate,
remove only old, unreferenced files under `/boot/EFI/nixos` and
`/boot/EFI/Linux/nixos-*`, and rerun `nixos-rebuild boot`.  Do not delete the
currently booted kernel or reboot until the rebuild succeeds.

## Verification checklist

```console
bootctl status                 # Secure Boot: enabled (user)
sudo sbctl status              # Setup Mode: disabled, Secure Boot: enabled
sudo sbctl verify              # systemd-boot + generation UKIs are signed
df -h /boot                    # keep free space for updates
ls -l /sys/firmware/efi/efivars/dbx-*   # dbx still present
```

Keys are deliberately outside the Nix store, so a `nixos-rebuild` does not
create or enroll them.  Keep an offline backup such as:

```console
sudo tar -C /var/lib -czf /path/to/offline-media/sbctl-backup.tar.gz sbctl
```
