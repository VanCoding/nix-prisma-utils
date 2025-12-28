# nix-prisma-utils

A nix library to make [prisma](https://www.prisma.io/) work in your nix shell

## How it works

Given the prisma engines commit and the hashes of each of the prisma engines binaries, the library downloads the binaries, patches their ELFs and combines them to a package that contains all the binaries, and a shell hook that sets the environment variables pointing to the binaries.

## Why not use...

### prisma engines as a flake

This is also a good option! But if you don't have a private nix binary cache, every developer checking out your project will have to build prisma engines.
Additionally, you'll have to manually keep the prisma-engines version in sync with the version in your package-lock.json file, which nix-prisma-utils detects automatically.

### prisma engines from nixpkgs

The drawback of this is that the version of prisma-engines from nixpkgs dictates which version of prisma you have to use in node.js.
With nix-prisma-utils it's the other way around. You can simply install prisma trhough npm or pnpm, and then let nix-prisma-utils do the rest.

## Let's go

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    prisma-utils.url = "github:VanCoding/nix-prisma-utils";
  };

  outputs =
    { nixpkgs, prisma-utils, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      prisma = prisma-utils.lib.prisma-factory {
        inherit pkgs;
        # leave the hash empty, nix will complain and tell you the right hash
        hash = "";
        npmLock = ./package-lock.json; # <--- path to our package-lock.json file that contains the version of prisma-engines
        # if you use another package manager from npm, choose yours from
        #   yarnLock = ./yarn.lock;
        #   pnpmLock = ./pnpm-lock.yaml;
        #   bunLock = ./bun.lock;
        # or if you want to specify the prisma commit directly
        #   version = {
        #     majorVersion = 7;
        #     commit = "....";
        #   };
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        env = prisma.env;
        # or, you can use `shellHook` instead of `env` to load the same environment variables.
        # shellHook = prisma.shellHook;
      };
    };
}
```

## Building prisma-engines from source

In some cases, it might be desirable to build the prisma engines from source using the nixpkgs derivation instead of relying on prebuilt binaries.
For example, this might be helpful when trying to use prisma on an architecture that is not officially supported by prisma (hence has no prebuilt binaries), but for which prisma-engines can be correctly built using the derivation in nixpkgs.

Note that this requires that the version of prisma-engines specified in the lockfile can be successfully built by the upstream derivation in nixpkgs, so it is not guaranteed that this approach can be successfully used for any version of prisma-engines. Also, only the major version prisma-engines 6 is supported at the moment.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    prisma-utils.url = "github:VanCoding/nix-prisma-utils";
  };

  outputs =
    { nixpkgs, prisma-utils, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      prisma = prisma-utils.lib.prisma-factory {
        inherit pkgs;
        # leave the hashes empty, nix will complain and tell you the right hash
        usePrismaFromPkgs = true;
        prismaEnginesGitHubHash = "";
        prismaEnginesCargoHash = "";
        npmLock = ./package-lock.json; # <--- path to our package-lock.json file that contains the version of prisma-engines
        # Lockfiles of other package managers are supported as well.
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        env = prisma.env;
      };
    };
}
```

## Legacy API

The [Legacy API](./legacy-api.md) (with fromNpmLock, fromYarnLock, etc.) is now deprecated and we recommend switching to the new API above.

## Contributing

Before contributing, please make sure that your code is formatted correctly by running

```sh
nix fmt
```

All tests (including format check) can be run by

```sh
nix flake check
```

## License

MIT
