{
  nixpkgs ? null,
  # if both are set, prefer pkgs over nixpkgs
  pkgs ? nixpkgs,
  opensslVersion ? "3.0.x", # can be 3.0.x, 1.1.x or 1.0.x
  openssl ? pkgs.openssl, # the openssl package to use
  introspection-engine-hash ? null,
  migration-engine-hash ? null,
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  schema-engine-hash ? null,
  binaryTargetBySystem ? {
    x86_64-linux = "debian";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin";
    aarch64-darwin = "darwin-arm64";
  },
}:
let
  utils = pkgs.callPackage ./utils/default.nix { };
  parsers = pkgs.callPackage ./parsers/default.nix { inherit utils; };
  fromCommit = pkgs.callPackage ./fromCommit.nix {
    inherit
      utils
      openssl
      opensslVersion
      introspection-engine-hash
      migration-engine-hash
      prisma-fmt-hash
      query-engine-hash
      libquery-engine-hash
      schema-engine-hash
      binaryTargetBySystem
      ;
  };
in
pkgs.lib.warnIf (nixpkgs != null)
  ''
    `nixpkgs` argument in nix-prisma-utils is deprecated. please replace it with `pkgs`.
    examples:
      if your code has `inherit nixpkgs;`, replace it with `pkgs = nixpkgs;`.
      if your code has `nixpkgs = pkgs;`, replace it with `pkgs = pkgs;` or `inherit pkgs;`.
  ''
  {
    inherit fromCommit;
    fromPnpmLock = path: fromCommit (parsers.pnpmLock path);
    fromNpmLock = path: fromCommit (parsers.npmLock path);
    fromYarnLock = path: fromCommit (parsers.yarnLock path);
    fromBunLock = path: fromCommit (parsers.bunLock path);
  }
