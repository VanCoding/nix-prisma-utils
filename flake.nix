{
  inputs.pkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs =
    { pkgs, flake-utils, ... }:
    let
      prisma-factory = import ./prisma.nix;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        nixpkgs = import pkgs { inherit system; };
      in
      {
        packages = import ./tests.nix { inherit prisma-factory nixpkgs; };
        devShells.default =
          let
            prisma = (
              (prisma-factory {
                inherit nixpkgs;
                prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s=";
                query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
                libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
                schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
              }).fromCommit
                "6a3747c37ff169c90047725a05a6ef02e32ac97e"
            );
          in
          nixpkgs.mkShell {
            buildInputs = [
              nixpkgs.nodejs-18_x
              nixpkgs.nodePackages.pnpm
              nixpkgs.stdenv.cc.cc.lib
              prisma.package
              nixpkgs.nixfmt-rfc-style
            ];
            shellHook = prisma.shellHook;
          };
      }
    )
    // {
      lib = {
        inherit prisma-factory;
      };
    };
}
