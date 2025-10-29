{
  nixpkgs ? null,
  # if both are set, prefer pkgs over nixpkgs
  pkgs ? nixpkgs,
  opensslVersion ? "3.0.x", # can be 3.0.x, 1.1.x or 1.0.x
  openssl ? pkgs.openssl, # the openssl package to use
  # new fetcher args
  hash ? null,
  components ? null, # components to fetch
  _commit ? null, # because package `commit` exists in nixpkgs
  npmLock ? null,
  yarnLock ? null,
  pnpmLock ? null,
  bunLock ? null,
  # legacy fetcher args
  introspection-engine-hash ? null,
  migration-engine-hash ? null,
  prisma-fmt-hash ? null,
  query-engine-hash ? null,
  libquery-engine-hash ? null,
  schema-engine-hash ? null,
  binaryTargetBySystem ? {
    x86_64-linux = "debian";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin";
    aarch64-darwin = "darwin-arm64";
  },
}: let
  inherit (pkgs) lib;
  parsers = pkgs.callPackage ./lib/parsers.nix {};
  binaryTarget = binaryTargetBySystem.${pkgs.system};
  commitValue =
    if _commit != null
    then _commit
    else if npmLock != null
    then fromNpmLock npmLock
    else if yarnLock != null
    then fromYarnLock yarnLock
    else if pnpmLock != null
    then fromPnpmLock pnpmLock
    else if bunLock != null
    then fromBunLock bunLock
    else null;
  fromCommit = commit:
    if builtins.stringLength commit != 40
    then throw "invalid commit: got ${commit}"
    else if hash != null
    then
      pkgs.callPackage ./lib/fetcher.nix {
        inherit
          commit
          openssl
          opensslVersion
          binaryTarget
          hash
          components
          ;
      }
    # use new fetcher
    else
      pkgs.callPackage ./lib/legacyFetcher.nix {
        inherit
          commit
          openssl
          opensslVersion
          binaryTarget
          prisma-fmt-hash
          query-engine-hash
          libquery-engine-hash
          introspection-engine-hash
          migration-engine-hash
          schema-engine-hash
          ;
      };
  fromNpmLock = file: fromCommit (parsers.parseNpmLock file);
  fromPnpmLock = file: fromCommit (parsers.parsePnpmLock file);
  fromYarnLock = file: fromCommit (parsers.parseYarnLock file);
  fromBunLock = file: fromCommit (parsers.parseBunLock file);
in
  lib.warnIf (nixpkgs != null)
  ''
    `nixpkgs` argument in nix-prisma-utils is deprecated. please replace it with `pkgs`.
    examples:
      if your code has `inherit nixpkgs;`, replace it with `pkgs = nixpkgs;`.
      if your code has `nixpkgs = pkgs;`, replace it with `pkgs = pkgs;` or `inherit pkgs;`.
  ''
  (
    if commitValue != null
    then # direct fetch
      fromCommit commitValue
    else {
      # builder pattern
      inherit fromCommit fromNpmLock fromYarnLock fromPnpmLock fromBunLock;
    }
  )
