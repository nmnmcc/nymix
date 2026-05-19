{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nym;
  system = pkgs.stdenv.hostPlatform.system;
  flakePackages = self.packages.${system} or (throw "nymix does not provide packages for ${system}");
  packageReleaseSet = package: package.passthru.nymVpnReleaseSet or null;
  packageVersion = package: package.passthru.nymVpnVersion or null;
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "services" "nym" "package" ]
      [
        "services"
        "nym"
        "app"
        "package"
      ]
    )
    (lib.mkRenamedOptionModule
      [ "services" "nym" "daemonPackage" ]
      [
        "services"
        "nym"
        "daemon"
        "package"
      ]
    )
  ];

  options.services.nym = {
    enable = lib.mkEnableOption "all default NymVPN components";

    app = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        defaultText = lib.literalExpression "config.services.nym.enable";
        description = "Whether to install the NymVPN desktop client.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = flakePackages.nym-vpn;
        defaultText = lib.literalExpression "nymix.packages.\${pkgs.stdenv.hostPlatform.system}.nym-vpn";
        description = "NymVPN desktop client package.";
      };
    };

    daemon = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        defaultText = lib.literalExpression "config.services.nym.enable";
        description = "Whether to install and start the nym-vpnd system daemon.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = flakePackages.nym-vpnd;
        defaultText = lib.literalExpression "nymix.packages.\${pkgs.stdenv.hostPlatform.system}.nym-vpnd";
        description = "Package providing the nym-vpnd daemon.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion =
          !(cfg.app.enable && cfg.daemon.enable)
          || (
            packageReleaseSet cfg.app.package != null
            && packageReleaseSet cfg.app.package == packageReleaseSet cfg.daemon.package
            && packageVersion cfg.app.package != null
            && packageVersion cfg.app.package == packageVersion cfg.daemon.package
          );
        message = ''
          services.nym.app.package and services.nym.daemon.package must use the same NymVPN X.Y.Z version and release set.
          Use packages from this flake together, or set both package passthru.nymVpnVersion and passthru.nymVpnReleaseSet values to the same official app/core pairing.
        '';
      }
    ];

    environment.systemPackages =
      lib.optional cfg.app.enable cfg.app.package ++ lib.optional cfg.daemon.enable cfg.daemon.package;

    services.dbus.enable = lib.mkIf cfg.daemon.enable true;

    systemd.services.nym-vpnd = lib.mkIf cfg.daemon.enable {
      description = "NymVPN daemon";
      wantedBy = [ "multi-user.target" ];
      before = [ "network-online.target" ];
      after = [
        "NetworkManager.service"
        "systemd-resolved.service"
      ];
      startLimitBurst = 6;
      startLimitIntervalSec = 24;
      path = with pkgs; [
        dbus
        iproute2
        iptables
        kmod
        nftables
        procps
        wireguard-tools
      ];
      serviceConfig = {
        ExecStart = "${lib.getExe' cfg.daemon.package "nym-vpnd"} -v run-as-service";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
