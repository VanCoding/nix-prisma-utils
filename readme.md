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

### Using `npm`

```nix
{
  inputs.pkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.prisma-utils.url = "github:VanCoding/nix-prisma-utils";

  outputs =
    { pkgs, prisma-utils, ... }:
    let
      nixpkgs = import pkgs { system = "x86_64-linux"; };
      prisma =
        (prisma-utils.lib.prisma-factory {
          inherit nixpkgs;
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s="; # just copy these hashes for now, and then change them when nix complains about the mismatch
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        }).fromNpmLock
          ./package-lock.json; # <--- path to our package-lock.json file that contains the version of prisma-engines
    in
    {
      devShells.x86_64-linux.default = nixpkgs.mkShell { shellHook = prisma.shellHook; };
    };
}

```

### Using `pnpm`

```nix
{
  inputs.pkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.prisma-utils.url = "github:VanCoding/nix-prisma-utils";

  outputs =
    { pkgs, prisma-utils, ... }:
    let
      nixpkgs = import pkgs { system = "x86_64-linux"; };
      prisma =
        (prisma-utils.lib.prisma-factory {
          inherit nixpkgs;
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s="; # just copy these hashes for now, and then change them when nix complains about the mismatch
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        }).fromPnpmLock
          ./pnpm-lock.yaml; # <--- path to our pnpm-lock.yaml file that contains the version of prisma-engines
    in
    {
      devShells.x86_64-linux.default = nixpkgs.mkShell { shellHook = prisma.shellHook; };
    };
}

```

### Using `bun`

```nix
{
  inputs.pkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.prisma-utils.url = "github:VanCoding/nix-prisma-utils";

  outputs =
    { pkgs, prisma-utils, ... }:
    let
      nixpkgs = import pkgs { system = "x86_64-linux"; };
      prisma =
        (prisma-utils.lib.prisma-factory {
          inherit nixpkgs;
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s="; # just copy these hashes for now, and then change them when nix complains about the mismatch
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        }).fromBunLock
          ./bun.lock; # <--- path to our bun.lock file that contains the version of prisma-engines.
          # NOTE: does not work with bun.lockb!
    in
    {
      devShells.x86_64-linux.default = nixpkgs.mkShell { shellHook = prisma.shellHook; };
    };
}
```

## Testing

`nix run .#test-all`

## License

MIT
