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
}:
let
  inherit (pkgs) lib;
  parsers = pkgs.callPackage ./lib/parsers.nix { };
  binaryTarget = binaryTargetBySystem.${pkgs.system};
  fromCommit =
    _commit:
    let
      # HACK: _commit may be "next-0c19ccc313cf9911a90d99d2ac2eb0280c76c513" instead of "0c19ccc313cf9911a90d99d2ac2eb0280c76c513"
      commit = lib.lists.last (lib.splitString "-" _commit);
      # prisma >= v7 has fewer components;
      isv7 = lib.strings.hasPrefix "next-" _commit;
    in
    if builtins.stringLength commit != 40 then
      throw "invalid commit: got ${commit}"
    else if hash != null then
      # use new fetcher
      pkgs.callPackage ./lib/fetcher.nix {
        inherit
          commit
          openssl
          opensslVersion
          binaryTarget
          hash
          components
          isv7
          ;
      }
    else
      pkgs.callPackage ./lib/legacyFetcher.nix {
        inherit
          commit
          openssl
          opensslVersion
          binaryTarget
          isv7
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
    if _commit != null then
      fromCommit _commit
    else if npmLock != null then
      fromNpmLock npmLock
    else if yarnLock != null then
      fromYarnLock yarnLock
    else if pnpmLock != null then
      fromPnpmLock pnpmLock
    else if bunLock != null then
      fromBunLock bunLock
    else
      {
        # builder pattern
        inherit
          fromCommit
          fromNpmLock
          fromYarnLock
          fromPnpmLock
          fromBunLock
          ;
      }
  )
