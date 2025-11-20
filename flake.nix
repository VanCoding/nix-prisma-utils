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
            fetcherMode = "new";
            inherit
              pkgs
              prisma-factory
              yarn-v1
              yarn-berry
              ;
          })
          // (pkgs.callPackages ./tests.nix {
            fetcherMode = "legacy";
            inherit
              pkgs
              prisma-factory
              yarn-v1
              yarn-berry
              ;
          })
          // {
            format = treefmt.config.build.check self;
            fetcher-assert-npm =
              let
                # force download debian for consistent hash across systems
                binaryTargetBySystem = {
                  x86_64-linux = "debian";
                  aarch64-linux = "debian";
                  x86_64-darwin = "debian";
                  aarch64-darwin = "debian";
                };
                prisma-legacy = prisma-factory {
                  inherit pkgs binaryTargetBySystem;
                  hash = "sha256-R9PG286KQTbzF0r/PPcShUkMiYam2prRh/JICjmhCZA=";
                };
                prisma-new =
                  lockName: lockFile:
                  prisma-factory {
                    inherit pkgs binaryTargetBySystem;
                    hash = "sha256-R9PG286KQTbzF0r/PPcShUkMiYam2prRh/JICjmhCZA=";
                    ${lockName} = lockFile;
                  };
              in
              assert
                (prisma-legacy.fromNpmLock ./npm/package-lock.json).env
                == (prisma-new "npmLock" ./npm/package-lock.json).env;
              pkgs.hello;
            prisma-next =
              (self.lib.prisma-factory {
                pkgs = pkgs;
                _commit = "next-0c19ccc313cf9911a90d99d2ac2eb0280c76c513";
                hash = {
                 x86_64-linux = "sha256-JWX+N/mmp9uJLcv4XFbQ3yg34fFf2BLIUpOLrrfTjEM=" ;
                 x86_64-darwin = "sha256-WNwFOoeDOebbfAh4y/NvZCyE9otaJdg2hHb4ifEFD+Y=";
                 aarch64-linux = "sha256-f9FuPZaGx0FwKo4pA9f8g82MTcAzYLwWslxjb7oqk6E=";
                 aarch64-darwin  = "sha256-NMI+JcP3epBO3V37D19TDgzivMnPekgrYqUrXB6qNV0=";
                }.${pkgs.system};
              }).package;
          };
        packages.default =
          (prisma-factory {
            inherit pkgs;
            hash = "sha256-R9PG286KQTbzF0r/PPcShUkMiYam2prRh/JICjmhCZA=";
            _commit = "6a3747c37ff169c90047725a05a6ef02e32ac97e";
          }).package;
        devShells.default =
          let
            prisma = prisma-factory {
              inherit pkgs;
              hash = "sha256-R9PG286KQTbzF0r/PPcShUkMiYam2prRh/JICjmhCZA=";
              _commit = "6a3747c37ff169c90047725a05a6ef02e32ac97e";
            };
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
