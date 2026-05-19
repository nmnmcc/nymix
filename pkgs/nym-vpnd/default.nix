{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dbus,
  dpkg,
  libmnl,
  libnftnl,
  sources,
}:
let
  pname = "nym-vpnd";
  version = sources.daemon.version;
  releaseSet = sources.releaseSet.key or "${sources.app.tag}/${sources.daemon.tag}";
  systemSource =
    sources.daemon.deb.${stdenv.hostPlatform.system}
      or (throw "NymVPN daemon deb is not available for ${stdenv.hostPlatform.system}");
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
    dbus
    libmnl
    libnftnl
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

    install -Dm755 usr/bin/nym-vpnd $out/bin/nym-vpnd
    install -Dm755 usr/bin/nym-exclude $out/bin/nym-exclude
    install -Dm444 usr/lib/systemd/system/nym-vpnd.service \
      $out/share/systemd/nym-vpnd.service

    runHook postInstall
  '';

  passthru = {
    nymVpnComponent = "daemon";
    nymVpnVersion = version;
    nymVpnReleaseSet = releaseSet;
  };

  meta = {
    description = "NymVPN daemon";
    homepage = "https://nym.com/download/linux";
    changelog = "https://github.com/nymtech/nym-vpn-client/releases/tag/${sources.daemon.tag}";
    license = lib.licenses.gpl3Only;
    mainProgram = "nym-vpnd";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
