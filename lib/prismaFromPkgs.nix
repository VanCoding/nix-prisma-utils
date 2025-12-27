{
  lib,
  callPackage,
  fetchFromGitHub,
  prisma-engines_6,
  prisma-engines_7,
  rust-bin,
  makeRustPlatform,
  # variables
  version,
  binaryTarget,
  prismaEnginesGitHubHash,
  prismaEnginesCargoHash,
}:

let
  componentsToFetch = (callPackage ./components.nix { }).fromVersion version;
  isDarwin = lib.strings.hasPrefix "darwin" binaryTarget;
  envFuncs = callPackage ./env.nix {
    inherit componentsToFetch;
  };
  inherit (envFuncs) toExportStyle mkEnv;

  pkgsPrismaEngines =
    if version.majorVersion == 6 then
      prisma-engines_6
    else if version.majorVersion == 7 then
      prisma-engines_7
    else
      throw "Version ${version.majorVersion} of prisma-engines is not supported,"
      + " only 6 and 7 are supported.";

  package = pkgsPrismaEngines.overrideAttrs (
    finalAttrs: oldAttrs:
    let
      rustToolchainPath = finalAttrs.src + "/rust-toolchain.toml";
      rust-toolchain =
        if builtins.pathExists rustToolchainPath then
          rust-bin.fromRustupToolchainFile rustToolchainPath
        else
          rust-bin.stable.latest.default;
      rustPlatform = makeRustPlatform {
        rustc = rust-toolchain;
        cargo = rust-toolchain;
      };
      _version = version; # avoid name clash
    in
    rec {
      src = fetchFromGitHub {
        owner = "prisma";
        repo = "prisma-engines";
        rev = _version.commit;
        hash = prismaEnginesGitHubHash;
      };
      pname = "prisma-engines_${toString _version.majorVersion}";
      version = _version.commit;

      cargoDeps = rustPlatform.fetchCargoVendor {
        inherit src;
        hash = prismaEnginesCargoHash;
      };
    }
  );
  env = mkEnv package;
in
rec {
  inherit package env;
  shellHook = toExportStyle env;
}
