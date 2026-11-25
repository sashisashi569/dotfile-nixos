{ pkgs, ... }:

{
  system.activationScripts.nixGc = {
    supportsDryActivation = false;
    text = ''
      # Profiles are named "system" (default) or "<branch>" under
      # system-profiles/ (see rebuild.sh --profile-name). Each is a
      # symlink like "master -> master-1-link -> /nix/store/...";
      # the "-<N>-link" entries are individual generations, not profiles
      # themselves, so exclude those when enumerating candidates.
      candidates=$(
        { ${pkgs.findutils}/bin/find /nix/var/nix/profiles -maxdepth 1 -type l
          ${pkgs.findutils}/bin/find /nix/var/nix/profiles/system-profiles -maxdepth 1 -type l 2>/dev/null; } \
          | ${pkgs.gnugrep}/bin/grep -vE -- '-[0-9]+-link$'
      )

      for profile in $candidates; do
        if [ "$(${pkgs.coreutils}/bin/readlink -f "$profile")" = "$systemConfig" ]; then
          echo "[gc] Deleting generations older than 3 in profile: $profile"
          ${pkgs.nix}/bin/nix-env \
            --profile "$profile" \
            --delete-generations +3
        fi
      done

      echo "[gc] Running nix-store --gc to remove unreferenced paths..."
      ${pkgs.nix}/bin/nix-store --gc
    '';
  };
}
