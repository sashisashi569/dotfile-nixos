# qBittorrent: GUI BitTorrent client covering the three wants - the built-in
# search tab (Python plugins from qbittorrent/search-plugins), partial
# downloads (per-file checkboxes / priorities / sequential), and a Qt6 GUI.
# nixpkgs builds it with trackerSearch=true, so python3 is already on PATH in
# the wrapper and search plugins work without extra setup.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    qbittorrent
  ];
}
