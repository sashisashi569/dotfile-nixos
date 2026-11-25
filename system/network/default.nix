# Networking policy shared by every host.  hostName is set by the host module.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  # systemd-resolved: stub resolver aggregating NM, Tailscale, and mDNS.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "false";
      MulticastDNS = "yes";
      LLMNR = "no";
    };
  };

  # Avahi (Bonjour): mDNS for .local discovery and service advertisement.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.tailscale.enable = true;
}
