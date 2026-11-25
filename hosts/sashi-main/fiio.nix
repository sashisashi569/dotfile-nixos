{
  config,
  lib,
  pkgs,
  ...
}:

{
  # FiiO BR15 R2R (USB vendor ID 2972, product ID 0142 — confirmed via
  # /sys/bus/usb/devices on this machine).
  #
  # FiiO Control's browser integration actually talks over WebHID
  # (navigator.hid), not WebUSB — confirmed via chrome://usb-internals
  # (raw USB access works fine, e.g. reading descriptors) and DevTools
  # console output showing WebHID chooser-dialog messages. WebHID needs
  # the /dev/hidraw* node (owned by the usbhid-bound HID interface, #3 on
  # this device) to be readable/writable by the user, not the raw
  # /dev/bus/usb/* node. Grant both, since a firmware-update flow might
  # still fall back to raw USB.
  #
  # Must be installed as its own rules file sorting *before*
  # systemd's 73-seat-late.rules, not via services.udev.extraRules (which
  # always lands in 99-local.rules). 73-seat-late.rules only runs the
  # uaccess builtin (which actually grants the ACL) if the "uaccess" tag
  # is already set when it evaluates — a rule at priority 99 adds the tag
  # too late, so the tag shows up but no ACL is ever applied.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "fiio-udev-rules";
      destination = "/etc/udev/rules.d/71-fiio.rules";
      text = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="2972", MODE="0660", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="2972", ATTRS{idProduct}=="0142", MODE="0660", TAG+="uaccess"
      '';
    })
  ];
}
