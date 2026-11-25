# Machine-specific kernel and device quirks for sashi-main.
#
# The shared kernel choice, NVIDIA stack and graphics baseline live in
# system/{boot,nvidia,graphics}.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Realtek RTL8125 2.5GbE: prefer the out-of-tree r8125 driver over the
  # generic r8169.
  boot.kernelModules = [
    "r8125"
    "v4l2loopback" # virtual camera device consumed by OBS's Virtual Camera
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    r8125
    v4l2loopback
  ];

  # exclusive_caps=1 is required for apps (browsers, video-call clients) to
  # detect the device as a usable webcam instead of just a capture device.
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"
  '';

  # Blacklist the generic r8169 so r8125 takes over, and the AMD iGPU's
  # amdgpu driver so the integrated GPU stays powered down / unused
  # (NVIDIA is the sole renderer on this machine).
  boot.blacklistedKernelModules = [
    "r8169"
    "amdgpu"
  ];
}
