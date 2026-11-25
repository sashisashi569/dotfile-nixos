{
  lib,
  stdenv,
  fetchFromGitHub,
  fcitx5,
  gettext,
  libglvnd,
  mozc,
  pkg-config,
  python3,
  qt6,
  unzip,
  writableTmpDirAsHomeHook,
  xdg-utils,
}:

# Mozkey is a Mozc fork with live conversion, local Zenz correction and
# punctuation/symbol single-key commit.  The Linux/fcitx5 port lives in
# soichi11208/fcitx5-mozkey and is built with the same Bazel machinery as
# nixpkgs' mozc / fcitx5-mozc, so vendor/hash handling is borrowed from
# `mozc.mkVendorDeps`.
let
  inherit (mozc)
    bazel
    bazelCommonArgs
    mkVendorDeps
    setupBazelVendor
    ;

  pname = "mozkey";
  version = "0.7.6";

  src = fetchFromGitHub {
    owner = "soichi11208";
    repo = "fcitx5-mozkey";
    rev = "f661afefba62634666ce1f83412fe5de1bf5d5bf";
    hash = "sha256-WUjR19P6MZGoSlZX6tJUOotggRy+ZXKJQcwX6h35ftA=";
  };

  nativeBuildInputs = [
    bazel
    gettext
    pkg-config
    python3
    qt6.wrapQtAppsHook
    unzip
    writableTmpDirAsHomeHook
  ];

  buildInputs = [
    fcitx5
    libglvnd
    qt6.qtbase
  ];

  includePath = lib.makeIncludePath buildInputs;
  libraryPath = lib.makeLibraryPath buildInputs;

  bazelArgs = bazelCommonArgs ++ [
    "--action_env=C_INCLUDE_PATH=${includePath}"
    "--action_env=CPLUS_INCLUDE_PATH=${includePath}"
    "--action_env=LIBRARY_PATH=${libraryPath}"
    "server:mozc_server"
    "gui/tool:mozc_tool"
    "renderer/qt:mozc_renderer"
    "unix/fcitx5:fcitx5-mozc.so"
    "unix:icons"
  ];

  vendorDeps = mkVendorDeps {
    inherit
      pname
      src
      version
      nativeBuildInputs
      buildInputs
      bazelArgs
      ;
    hash = "sha256-h13AoerdKWiZWMNd7uKq6WLkMegbvIcY79DMqbm2KTw=";
  };
in
stdenv.mkDerivation {
  inherit
    pname
    version
    src
    nativeBuildInputs
    buildInputs
    ;

  strictDeps = true;
  __structuredAttrs = true;

  env.USE_BAZEL_VERSION = bazel.version;
  # Work around Bazel's username lookup with sandbox=false and auto-allocate-uids=true.
  env.USER = "nixbld";

  postPatch = ''
    cd src

    ${setupBazelVendor vendorDeps}

    # Qt 6.12's uic rejects widget class names with a leading global
    # qualifier; the fork still ships one in dictionary_tool.ui.
    sed -i 's/::mozc::gui::DictionaryContentTableWidget/mozc::gui::DictionaryContentTableWidget/g' \
      gui/dictionary_tool/dictionary_tool.ui

    # Make live conversion more eager than upstream's defaults (228 ms
    # debounce, minimum 2 characters). These constants are used whenever the
    # user has not stored an explicit value in ~/.config/mozc/config1.db, and
    # the config dialog shows the same values.
    substituteInPlace session/session.cc \
      --replace-fail "kDefaultLiveConversionDelayMillisec = 228" \
        "kDefaultLiveConversionDelayMillisec = 100" \
      --replace-fail "kDefaultLiveConversionMinKeyLength = 2" \
        "kDefaultLiveConversionMinKeyLength = 1"
    substituteInPlace gui/config_dialog/config_dialog.cc \
      --replace-fail "kDefaultLiveConversionDelayMsec = 228" \
        "kDefaultLiveConversionDelayMsec = 100" \
      --replace-fail "kDefaultLiveConversionMinKeyLength = 2" \
        "kDefaultLiveConversionMinKeyLength = 1"
    substituteInPlace protocol/config.proto \
      --replace-fail "live_conversion_delay_msec = 70 [default = 228]" \
        "live_conversion_delay_msec = 70 [default = 100]" \
      --replace-fail "live_conversion_min_key_length = 71 [default = 2]" \
        "live_conversion_min_key_length = 71 [default = 1]"

    # Point the addon at this package's own binaries instead of /usr/lib/mozc.
    substituteInPlace config.bzl \
      --replace-fail "/usr/bin/xdg-open" "${xdg-utils}/bin/xdg-open" \
      --replace-fail "/usr/lib/mozc" "$out/lib/mozc" \
      --replace-fail "/usr/share/icons/mozc" "$out/share/icons/mozc"
  '';

  buildPhase = ''
    runHook preBuild

    bazel build --lockfile_mode=error --vendor_dir=vendor_dir ${lib.escapeShellArgs bazelArgs}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm555 bazel-bin/server/mozc_server "$out/lib/mozc/mozc_server"
    install -Dm555 bazel-bin/gui/tool/mozc_tool "$out/lib/mozc/mozc_tool"
    install -Dm555 bazel-bin/renderer/qt/mozc_renderer "$out/lib/mozc/mozc_renderer"
    install -Dm444 bazel-bin/unix/fcitx5/fcitx5-mozc.so "$out/lib/fcitx5/fcitx5-mozc.so"

    install -Dm444 unix/fcitx5/mozc-addon.conf "$out/share/fcitx5/addon/mozc.conf"
    install -Dm444 unix/fcitx5/mozc.conf "$out/share/fcitx5/inputmethod/mozc.conf"

    unzip -q bazel-bin/unix/icons.zip -d icons
    iconsScalable="$out/share/icons/hicolor/scalable/apps"
    icons128="$out/share/icons/hicolor/128x128/apps"
    install -Dm444 icons/mozc.svg "$iconsScalable/org.fcitx.Fcitx5.fcitx_mozc.svg"
    ln -s org.fcitx.Fcitx5.fcitx_mozc.svg "$iconsScalable/fcitx_mozc.svg"
    install -Dm444 icons/mozc.png "$icons128/org.fcitx.Fcitx5.fcitx_mozc.png"
    ln -s org.fcitx.Fcitx5.fcitx_mozc.png "$icons128/fcitx_mozc.png"
    for icon in alpha_full alpha_half direct hiragana katakana_full katakana_half; do
      install -Dm444 "icons/$icon.svg" \
        "$iconsScalable/org.fcitx.Fcitx5.fcitx_mozc_$icon.svg"
      ln -s "org.fcitx.Fcitx5.fcitx_mozc_$icon.svg" \
        "$iconsScalable/fcitx_mozc_$icon.svg"
    done

    while read -r lang; do
      [ -n "$lang" ] || continue
      po="unix/fcitx5/po/$lang.po"
      [ -f "$po" ] || continue
      mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
      msgfmt "$po" -o "$out/share/locale/$lang/LC_MESSAGES/fcitx5-mozc.mo"
    done < unix/fcitx5/po/LINGUAS

    install -Dm444 ../LICENSE "$out/share/licenses/$pname/LICENSE"

    runHook postInstall
  '';

  passthru = {
    inherit vendorDeps;
  };

  meta = {
    description = "Mozc fork with live conversion and local Zenz correction (fcitx5 port)";
    homepage = "https://github.com/soichi11208/fcitx5-mozkey";
    license = lib.licenses.free;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "mozc_tool";
  };
}
