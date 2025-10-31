{
  pkgs,
  prisma-factory,
}:
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
{
  assert-npm-equals =
    assert
      (prisma-legacy.fromNpmLock ../npm/package-lock.json).env
      == (prisma-new "npmLock" ../npm/package-lock.json).env;
    pkgs.hello;
}
