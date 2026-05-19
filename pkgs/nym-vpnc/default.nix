{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  sources,
}:
let
  pname = "nym-vpnc";
  version = sources.vpnc.version;
  releaseSet = sources.releaseSet.key or "${sources.app.tag}/${sources.vpnc.tag}";
  systemSource =
    sources.vpnc.deb.${stdenv.hostPlatform.system}
      or (throw "NymVPN command-line client deb is not available for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (systemSource) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/nym-vpnc $out/bin/nym-vpnc

    runHook postInstall
  '';

  passthru = {
    nymVpnComponent = "vpnc";
    nymVpnVersion = version;
    nymVpnReleaseSet = releaseSet;
  };

  meta = {
    description = "NymVPN command-line client";
    homepage = "https://nym.com/download/linux";
    changelog = "https://github.com/nymtech/nym-vpn-client/releases/tag/${sources.vpnc.tag}";
    license = lib.licenses.gpl3Only;
    mainProgram = "nym-vpnc";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
