# nymix

Nix packages and a NixOS module for running the official NymVPN Linux release.

Translations: [简体中文](README.zh-CN.md), [Русский](README.ru-RU.md),
[فارسی](README.fa-IR.md), [Türkçe](README.tr-TR.md).

Use this flake if you want NymVPN on NixOS with the desktop app, the
`nym-vpnc` command-line client, and the `nym-vpnd` system daemon wired together
through systemd, D-Bus, and polkit.

## What you get

- `nym-vpn`: the NymVPN desktop app.
- `nym-vpnc`: the NymVPN command-line client.
- `nym-vpnd`: the NymVPN daemon.
- A NixOS module at `nymix.nixosModules.default`.
- A package overlay at `nymix.overlays.default`.

Supported systems are `x86_64-linux` and `aarch64-linux`.

You need Nix with flakes enabled.

## NixOS setup

Add `nymix` to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nymix.url = "github:nmnmcc/nymix";
  };

  outputs =
    {
      nixpkgs,
      nymix,
      ...
    }:
    {
      nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nymix.nixosModules.default
          {
            services.nym.enable = true;
          }
        ];
      };
    };
}
```

Then rebuild your system:

```sh
sudo nixos-rebuild switch --flake .#your-host
```

After rebuilding, open **NymVPN** from your desktop launcher or run the CLI:

```sh
nym-vpnc --help
```

The NixOS module also starts the daemon:

```sh
systemctl status nym-vpnd
```

## Installing only some components

`services.nym.enable = true` enables the app, CLI, and daemon. If you want to
choose components yourself, enable them individually:

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

For example, a CLI-focused setup can enable only the client and daemon:

```nix
{
  services.nym = {
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

When the daemon is enabled, the module enables D-Bus and polkit, installs the
daemon policy, and allows active local sessions to access the daemon without an
extra password prompt.

## Using the packages directly

You can run the packages directly without the NixOS module:

```sh
nix run github:nmnmcc/nymix#nym-vpn
nix run github:nmnmcc/nymix#nym-vpnc -- --help
nix run github:nmnmcc/nymix#nym-vpnd -- --help
```

For a full VPN setup on NixOS, prefer the module above. It configures the daemon
service and permissions for you.

If you want the packages in your own package set, use the overlay:

```nix
{
  nixpkgs.overlays = [
    nymix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    nym-vpn
    nym-vpnc
    nym-vpnd
  ];
}
```

## Updating

If your system uses `nymix` as a flake input, update it like any other input:

```sh
nix flake update nymix
sudo nixos-rebuild switch --flake .#your-host
```

This repository pins the upstream NymVPN app and core releases in
`sources.json`. The app, CLI, and daemon are kept on the same upstream `X.Y.Z`
release pair so that mixed versions are not installed together by accident.

## Troubleshooting

Check whether the daemon is running:

```sh
systemctl status nym-vpnd
```

Read daemon logs from the current boot:

```sh
journalctl -u nym-vpnd -b
```

If Nix says the package is not available for your platform, make sure your host
is either `x86_64-linux` or `aarch64-linux`.

## License

The packaged NymVPN binaries are distributed by the upstream NymVPN project.
This flake packages those Linux releases for Nix and NixOS.
