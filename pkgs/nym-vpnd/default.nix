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
  version = sources.vpnd.version;
  releaseSet = sources.releaseSet.key or "${sources.app.tag}/${sources.vpnd.tag}";
  systemSource =
    sources.vpnd.deb.${stdenv.hostPlatform.system}
      or (throw "NymVPN daemon deb is not available for ${stdenv.hostPlatform.system}");
  polkitPolicy = builtins.toFile "com.nymvpn.vpnd.unix-access.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <policyconfig>
      <action id="com.nymvpn.vpnd.unix-access">
        <description>Connect via unix socket</description>
        <message>Authentication is required to connect to the daemon</message>

        <defaults>
          <allow_any>auth_admin</allow_any>
          <allow_inactive>auth_admin</allow_inactive>
          <allow_active>auth_self</allow_active>
        </defaults>
      </action>
    </policyconfig>
  '';
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
    install -Dm444 ${polkitPolicy} \
      $out/share/polkit-1/actions/com.nymvpn.vpnd.unix-access.policy

    runHook postInstall
  '';

  passthru = {
    nymVpnComponent = "vpnd";
    nymVpnVersion = version;
    nymVpnReleaseSet = releaseSet;
  };

  meta = {
    description = "NymVPN daemon";
    homepage = "https://nym.com/download/linux";
    changelog = "https://github.com/nymtech/nym-vpn-client/releases/tag/${sources.vpnd.tag}";
    license = lib.licenses.gpl3Only;
    mainProgram = "nym-vpnd";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
