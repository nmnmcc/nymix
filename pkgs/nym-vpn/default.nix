{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  cairo,
  dbus,
  desktop-file-utils,
  gdk-pixbuf,
  glib-networking,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  makeDesktopItem,
  openssl,
  pciutils,
  wrapGAppsHook3,
  webkitgtk_4_1,
  sources,
}:
let
  pname = "nym-vpn";
  version = sources.app.version;
  binarySource =
    sources.app.binary.${stdenv.hostPlatform.system}
      or (throw "NymVPN binary is not available for ${stdenv.hostPlatform.system}");
  src = fetchurl {
    inherit (binarySource) url hash;
  };
  icon = fetchurl {
    inherit (sources.app.icon) url hash;
  };
  desktopItem = makeDesktopItem {
    name = "NymVPN";
    desktopName = "NymVPN";
    comment = "NymVPN desktop client";
    exec = "env LOG_FILE=1 RUST_LOG=info,nym_vpn_app=debug ${pname}";
    icon = "nym-vpn-app";
    mimeTypes = [ "x-scheme-handler/nymvpn" ];
    categories = [ "Network" ];
    startupWMClass = "nym-vpn-app";
    terminal = false;
    tryExec = pname;
  };
  releaseSet = sources.releaseSet.key or "${sources.app.tag}/${sources.vpnd.tag}";
  runtimePath = lib.makeBinPath [
    desktop-file-utils
    pciutils
  ];
  runtimeLibraryPath = lib.makeLibraryPath [
    libayatana-appindicator
  ];
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    glib-networking
    glib
    gsettings-desktop-schemas
    gtk3
    libayatana-appindicator
    libsoup_3
    openssl
    stdenv.cc.cc.lib
    webkitgtk_4_1
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/${pname}
    ln -s $out/bin/${pname} $out/bin/nym-vpn-app
    install -Dm444 ${icon} $out/share/icons/hicolor/scalable/apps/nym-vpn-app.svg
    install -Dm444 ${desktopItem}/share/applications/NymVPN.desktop \
      $out/share/applications/NymVPN.desktop

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${runtimePath}
      --prefix LD_LIBRARY_PATH : ${runtimeLibraryPath}
    )
  '';

  passthru = {
    nymVpnComponent = "app";
    nymVpnVersion = version;
    nymVpnReleaseSet = releaseSet;
  };

  meta = {
    description = "NymVPN desktop client";
    homepage = "https://nym.com/download/linux";
    changelog = "https://github.com/nymtech/nym-vpn-client/releases/tag/${sources.app.tag}";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
