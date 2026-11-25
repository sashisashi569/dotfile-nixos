# Local copy of ~/scripts/rename-music-by-tags.  Keeping it in this repository
# (instead of a `path:` flake input) lets the GitHub Action evaluate the flake
# on a clean runner.
{
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "rename-music-by-tags";

  runtimeInputs = [
    (python3.withPackages (ps: [ ps.mutagen ]))
  ];

  text = ''
    exec python3 ${./rename_music_by_tags.py} "$@"
  '';

  meta = {
    description = "Rename music files from their tags";
    mainProgram = "rename-music-by-tags";
  };
}
