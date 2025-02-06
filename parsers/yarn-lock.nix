{
  lib,
  utils,
}:
path:
let
  # find this line from yarn.lock:
  # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
  yarnLockParser1 =
    file:
    let
      versionLine =
        lib.lists.findFirst
          (line: builtins.length (lib.strings.splitString "@prisma/engines-version" line) >= 2)
          # else
          (throw ''
            nix-prisma-utils/yarnLockParser1: package @prisma/engines-version not found in lockfile ${path} .
            please make sure you have installed `@prisma/client`.
            if you have already installed `@prisma/client` and still see this, please report this to nix-prisma-utils.
          '')
          (utils.lines file);
      # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
      # -> ["@prisma/engines-version@npm" "6" "3" "0-17" "acc0b9dd43eb689cbd20c9470515d719db10d0b0"]
      # -> acc0b9dd43eb689cbd20c9470515d719db10d0b0
      version = lib.lists.last (
        utils.splitMultipleAndFilterEmpty [
          "\""
          ":"
          "."
        ] versionLine
      );
    in
    version;
  isYarnLockV1 =
    file:
    lib.lists.any (line: lib.strings.trim line == "# yarn lockfile v1") (
      lib.strings.splitString "\n" file
    );
  # example line:
  # "@prisma/engines-version@6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
  yarnV1LockParser = yarnLockParser1;
  # example line:
  # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
  yarnBerryLockParsers = {
    "8" = yarnLockParser1;
  };

  lockfile = builtins.readFile path;
  parse =
    if isYarnLockV1 lockfile then
      yarnV1LockParser
    else
      let
        lockfileVersion = builtins.toString (utils.readYAML path).__metadata.version;
      in
      yarnBerryLockParsers.${lockfileVersion} or (throw ''
        nix-prisma-utils: unknown lockfile version ${lockfileVersion}.
        please report this to nix-prisma-utils with your lockfile.
      '');
in
(parse lockfile)
