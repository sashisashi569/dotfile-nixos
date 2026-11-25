{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Keychron keyboards (QMK/VIA) use USB vendor ID 3434. Grant hidraw access
  # to the active logged-in user so WebUSB-based configurators (e.g. VIA)
  # can talk to the keyboard without root.
  #
  # This must be installed as its own rules file sorting *before*
  # systemd's 73-seat-late.rules, not via services.udev.extraRules (which
  # always lands in 99-local.rules). 73-seat-late.rules only runs the
  # uaccess builtin (which actually grants the ACL) if the "uaccess" tag
  # is already set when it evaluates — a rule at priority 99 adds the tag
  # too late, so the tag shows up but no ACL is ever applied.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "keychron-udev-rules";
      destination = "/etc/udev/rules.d/71-keychron.rules";
      text = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="3434", MODE="0660", TAG+="uaccess"

        # Firmware flashing (DFU) mode: on reset the keyboard re-enumerates as
        # a generic STM32 DFU bootloader device (0483:df11), not as 3434:xxxx.
        # Confirmed via udevadm monitor while resetting a Keychron Q3 HE.
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0660", TAG+="uaccess"
      '';
    })
  ];
}
