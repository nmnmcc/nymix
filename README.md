# nymix

Nix packages and a NixOS module for the upstream NymVPN Linux release.
The desktop app package uses Nym's raw Linux binary and Nixpkgs WebKitGTK.

## Usage

Add this flake as an input and import its NixOS module:

```nix
{
  inputs.nymix.url = "github:nmnmcc/nymix";

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

`services.nym.enable = true;` installs the NymVPN desktop package, installs the
`nym-vpnc` command-line client, installs the `nym-vpnd` daemon package, enables
D-Bus, and starts `nym-vpnd.service`.

Components can also be enabled independently:

```nix
{
  services.nym = {
    app.enable = true;
    vpnc.enable = true;
    vpnd.enable = true;
  };
}
```

When multiple components are enabled, their packages must come from the same
official NymVPN app/core release pairing with the exact same `X.Y.Z` version.
The updater records that pairing in `sources.json` and the NixOS module rejects
mixed package sets across the desktop app, `nym-vpnc`, and `nym-vpnd`.

## Updates

`.github/workflows/update-nym.yml` runs every day and can also be triggered
manually. It scans `nymtech/nym-vpn-client` releases for the newest stable Linux
app/core `X.Y.Z` version that exists in both release streams and has all
required Linux assets for the desktop app, `nym-vpnc`, and `nym-vpnd`, rewrites
`sources.json`, runs `nix flake check`, and commits directly to the repository
default branch when upstream changed.

For fully unattended updates, set the repository's GitHub Actions workflow
permissions to read and write. If the default branch is protected, allow the
`github-actions[bot]` token to bypass the rule or use a bot token with that
permission.
