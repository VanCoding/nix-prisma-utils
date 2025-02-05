{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
    }:
    let
      prisma-factory = import ./prisma.nix;
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        yarn-v1 = pkgs.writeShellApplication {
          name = "yarn-v1";
          checkPhase = "";
          runtimeInputs = [ pkgs.yarn ];
          text = "yarn $@";
        };
        yarn-berry = pkgs.writeShellApplication {
          name = "yarn-berry";
          checkPhase = "";
          runtimeInputs = [ pkgs.yarn-berry ];
          text = "yarn $@";
        };
        treefmt = treefmt-nix.lib.evalModule pkgs {
          # nixfmt is nixfmt-rfc-style
          programs.nixfmt.enable = true;
        };
      in
      {
        formatter = treefmt.config.build.wrapper;
        checks =
          (pkgs.callPackages ./tests.nix {
            inherit
              pkgs
              prisma-factory
              yarn-v1
              yarn-berry
              ;
          })
          // {
            format = treefmt.config.build.check self;
          };
        devShells.default =
          let
            prisma = (
              (prisma-factory {
                inherit pkgs;
                prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s=";
                query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
                libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
                schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
              }).fromCommit
                "6a3747c37ff169c90047725a05a6ef02e32ac97e"
            );
          in
          pkgs.mkShell {
            buildInputs = [
              pkgs.nodejs-18_x
              pkgs.pnpm
              pkgs.bun
              pkgs.stdenv.cc.cc.lib
              prisma.package
              pkgs.nixfmt-rfc-style
              yarn-v1
              yarn-berry
            ];
            env = prisma.env;
          };
      }
    )
    // {
      lib = {
        inherit prisma-factory;
      };
    };
}
