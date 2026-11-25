# NVIDIA renderer stack.  Imported only by hosts that actually have an NVIDIA
# GPU; the laptop uses the graphics baseline without this module.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # VA-API bridge for NVDEC hardware video decoding, plus the OpenCL ICD
  # loader (the implementation comes from the NVIDIA driver).
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
    ocl-icd
  ];

  # The NVIDIA driver ships its OpenCL implementation and ICD
  # (libnvidia-opencl.so + nvidia.icd), but the ICD only lands under
  # /run/opengl-driver/etc, which ocl-icd does not scan.  Register it in the
  # standard vendor directory so c2me-ocl and other OpenCL apps find it.
  environment.etc."OpenCL/vendors/nvidia.icd".source =
    "${config.hardware.nvidia.package}/etc/OpenCL/vendors/nvidia.icd";

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    LIBVA_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    NVD_BACKEND = "direct";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
