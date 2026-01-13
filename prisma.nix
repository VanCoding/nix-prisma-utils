{
  nixpkgs ? null,
  # if both are set, prefer pkgs over nixpkgs
  pkgs ? nixpkgs,
  opensslVersion ? "3.0.x", # can be 3.0.x, 1.1.x or 1.0.x
  openssl ? pkgs.openssl, # the openssl package to use
  # new fetcher args
  hash ? null,
  versionString ? null,
  version ? null,
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
  # prismaFromPkgs arguments
  rust-bin,
  usePrismaFromPkgs ? false,
  prismaEnginesGitHubHash ? null,
  prismaEnginesCargoHash ? null,
}:
let
  inherit (pkgs) lib;
  parsers = pkgs.callPackage ./lib/parsers.nix { };
  hostSystem = pkgs.stdenv.hostPlatform.system;
  binaryTarget = binaryTargetBySystem.${hostSystem};
  fromVersionString =
    versionString:
    let
      version = parsers.parseVersionString versionString;
    in
    fromVersion version;
  fromVersion =
    version:
    if usePrismaFromPkgs then
      if prismaEnginesGitHubHash == null || prismaEnginesCargoHash == null then
        throw ''
          When using `usePrismaFromPkgs = true`, you must provide both
          `prismaEnginesGitHubHash` and `prismaEnginesCargoHash` arguments.
          Start by setting them both to empty strings "" one by one,
          and then run `nix build` to get the expected hash in the error message.
        ''
      else
        pkgs.callPackage ./lib/prismaFromPkgs.nix {
          inherit
            rust-bin

            version
            binaryTarget
            prismaEnginesGitHubHash
            prismaEnginesCargoHash
            ;
        }
    else if hash != null then
      # use new fetcher
      pkgs.callPackage ./lib/fetcher.nix {
        inherit
          openssl
          opensslVersion
          binaryTarget
          hash
          version
          ;
      }
    else
      pkgs.callPackage ./lib/legacyFetcher.nix {
        inherit
          openssl
          opensslVersion
          binaryTarget
          prisma-fmt-hash
          query-engine-hash
          libquery-engine-hash
          introspection-engine-hash
          migration-engine-hash
          schema-engine-hash
          version
          ;
      };
  fromNpmLock = file: fromVersionString (parsers.parseNpmLock file);
  fromPnpmLock = file: fromVersionString (parsers.parsePnpmLock file);
  fromYarnLock = file: fromVersionString (parsers.parseYarnLock file);
  fromBunLock = file: fromVersionString (parsers.parseBunLock file);
in
lib.warnIf (nixpkgs != null)
  ''
    `nixpkgs` argument in nix-prisma-utils is deprecated. please replace it with `pkgs`.
    examples:
      if your code has `inherit nixpkgs;`, replace it with `pkgs = nixpkgs;`.
      if your code has `nixpkgs = pkgs;`, replace it with `pkgs = pkgs;` or `inherit pkgs;`.
  ''
  (
    if version != null then
      fromVersion version
    else if versionString != null then
      fromVersionString versionString
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
          fromVersionString
          fromVersion
          fromNpmLock
          fromYarnLock
          fromPnpmLock
          fromBunLock
          ;

        fromCommit =
          commit:
          builtins.throw "nix-prisma-utils: fromCommit is no longer supported. please set either npmLock, yarnLock, pnpmLock, bunLock or use fromVersion instead.";

      }
  )
