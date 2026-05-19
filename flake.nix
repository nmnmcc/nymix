{
  description = "Nix packages and NixOS module for Nym VPN";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
    in
    {
      overlays.default = final: prev: {
        nym-vpn = final.callPackage ./pkgs/nym-vpn { inherit sources; };
        nym-vpnc = final.callPackage ./pkgs/nym-vpnc { inherit sources; };
        nym-vpnd = final.callPackage ./pkgs/nym-vpnd { inherit sources; };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) nym-vpn nym-vpnc nym-vpnd;
          default = pkgs.nym-vpn;
        }
      );

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) nym-vpn nym-vpnc nym-vpnd;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              curl
              jq
              nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      nixosModules.nym = import ./modules/nym.nix { inherit self; };
      nixosModules.default = self.nixosModules.nym;
    };
}
