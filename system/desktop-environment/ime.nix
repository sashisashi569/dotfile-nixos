# Japanese input: fcitx5 with Mozkey, a Mozc fork with live conversion,
# local Zenz correction and single-key punctuation commit.
{ pkgs, ... }:

let
  mozkey = pkgs.callPackage ../../packages/mozkey { };
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      mozkey
      fcitx5-gtk
    ];
    fcitx5.waylandFrontend = true;
  };

  # Wayland-native IME environment.  GTK_IM_MODULE is intentionally unset:
  # GTK4 Wayland uses the text-input protocol directly.
  environment.variables = {
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx"; # XWayland fallback
    SDL_IM_MODULE = "fcitx";
  };
}
