{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  desktop-file-utils,
  sources,
}:
let
  pname = "nym-vpn";
  version = sources.app.version;
  systemSource =
    sources.app.appImage.${stdenv.hostPlatform.system}
      or (throw "NymVPN AppImage is not available for ${stdenv.hostPlatform.system}");
  src = fetchurl {
    inherit (systemSource) url hash;
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
  releaseSet = sources.releaseSet.key or "${sources.app.tag}/${sources.daemon.tag}";
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ desktop-file-utils ];

  extraInstallCommands = ''
    ln -s $out/bin/${pname} $out/bin/nym-vpn-app

    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/32x32/apps/nym-vpn-app.png \
      $out/share/icons/hicolor/32x32/apps/nym-vpn-app.png
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/128x128/apps/nym-vpn-app.png \
      $out/share/icons/hicolor/128x128/apps/nym-vpn-app.png
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/256x256@2/apps/nym-vpn-app.png \
      $out/share/icons/hicolor/256x256@2/apps/nym-vpn-app.png

    desktop-file-install \
      --dir $out/share/applications \
      --set-key Exec --set-value "env LOG_FILE=1 RUST_LOG=info,nym_vpn_app=debug ${pname}" \
      --set-key TryExec --set-value ${pname} \
      --set-key Icon --set-value nym-vpn-app \
      ${appimageContents}/usr/share/applications/NymVPN.desktop
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
