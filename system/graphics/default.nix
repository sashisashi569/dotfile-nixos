# Vendor-neutral graphics baseline.  The NVIDIA renderer stack is a separate
# module so the laptop (Intel/AMD iGPU) never imports it.
{
  ...
}:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
