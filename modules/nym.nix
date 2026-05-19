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
  enabledPackages =
    lib.optional cfg.app.enable cfg.app.package
    ++ lib.optional cfg.vpnc.enable cfg.vpnc.package
    ++ lib.optional cfg.vpnd.enable cfg.vpnd.package;
  enabledPackagesUseSameReleaseSet =
    builtins.length enabledPackages < 2
    || (
      let
        firstPackage = builtins.head enabledPackages;
        firstReleaseSet = packageReleaseSet firstPackage;
        firstVersion = packageVersion firstPackage;
      in
      firstReleaseSet != null
      && firstVersion != null
      && lib.all (
        package: packageReleaseSet package == firstReleaseSet && packageVersion package == firstVersion
      ) enabledPackages
    );
in
{
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

    vpnc = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        defaultText = lib.literalExpression "config.services.nym.enable";
        description = "Whether to install the nym-vpnc command-line client.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = flakePackages.nym-vpnc;
        defaultText = lib.literalExpression "nymix.packages.\${pkgs.stdenv.hostPlatform.system}.nym-vpnc";
        description = "Package providing the nym-vpnc command-line client.";
      };
    };

    vpnd = {
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
        assertion = enabledPackagesUseSameReleaseSet;
        message = ''
          Enabled services.nym packages must use the same NymVPN X.Y.Z version and release set.
          Use packages from this flake together, or set each package's passthru.nymVpnVersion and passthru.nymVpnReleaseSet values to the same official app/core pairing.
        '';
      }
    ];

    environment.systemPackages =
      lib.optional cfg.app.enable cfg.app.package
      ++ lib.optional cfg.vpnc.enable cfg.vpnc.package
      ++ lib.optional cfg.vpnd.enable cfg.vpnd.package;

    services.dbus.enable = lib.mkIf cfg.vpnd.enable true;

    systemd.services.nym-vpnd = lib.mkIf cfg.vpnd.enable {
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
        ExecStart = "${lib.getExe' cfg.vpnd.package "nym-vpnd"} -v run-as-service";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
