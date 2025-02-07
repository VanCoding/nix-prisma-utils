{ utils }:
path:
let
  lockfile = utils.fromJSONWithTrailingCommas (
    assert builtins.typeOf path == "path";
    builtins.readFile path
  );
  bunLockParsers = {
    # example:
    # nu> open bun.lock | from json | get packages.@prisma/engines-version.0
    # @prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e
    "0" = bunLockParsers."1";
    "1" =
      lock:
      utils.afterLastDot (
        builtins.elemAt (lock."packages"."@prisma/engines-version" or (throw ''
          nix-prisma-utils: lockfile parsing error: package @prisma/engines-version not found.
          please make sure that you have @prisma/client installed.
        '')
        ) 0
      );
  };
  lockfileVersion = builtins.toString lockfile."lockfileVersion";
  parser =
    bunLockParsers.${lockfileVersion} or (throw ''
      nix-prisma-utils: Unsupported lockfile version: ${lockfileVersion}
      nix-prisma-utils currently supports bun.lock version of 0 and 1.
    '');
in
parser lockfile
