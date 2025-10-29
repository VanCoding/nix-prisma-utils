{
  lib,
  callPackage,
}: let
  lines = s: lib.strings.splitString "\n" s;

  # example:
  # splitMultiple ["|" "," "-"] "a-|b,c-d"
  # -> ["a" "" "b" "c" "d"]
  splitMultiple = delims: s: _splitMultiple delims [s];
  # example:
  # _splitMultiple ["|" "," "-"] ["a-|b,c-d"]
  # -> ["a" "" "b" "c" "d"]
  _splitMultiple = delims: list:
    if builtins.length delims == 0
    then list
    else let
      splitStr = map (str: lib.strings.splitString (builtins.elemAt delims 0) str) list;
    in
      _splitMultiple (lib.drop 1 delims) (lib.lists.concatLists splitStr);
  splitMultipleAndFilterEmpty = delims: s: builtins.filter (str: str != "") (splitMultiple delims s);
  # example:
  # a.b123c.d.e12345
  # => e12345
  afterLastDot = text: lib.lists.last (lib.strings.splitString "." text);

  readYAML = callPackage ./lib/readYAML.nix {};
  # polyfill: the function in nixis implemented on Dec 6, 2024. replace this with one from lib after 24.11 reaches EOL.
in {
  parsePnpmLock = path: let
    parsePnpmLockVersion = pnpmLock:
      if lib.strings.hasPrefix "lockfileVersion: 5" pnpmLock
      then "5"
      else if lib.strings.hasPrefix "lockfileVersion: '6" pnpmLock
      then "6"
      else "9";
    pnpmLockParsers = {
      # example line:
      # /@prisma/engines-version/5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
      "5" = pnpmLock: let
        version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split "@prisma/engines-version/" pnpmLock) 2)) 0;
      in
        lib.lists.last (lib.strings.splitString "." version);

      # example line:
      # /@prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
      "6" = pnpmLock: let
        version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split "@prisma/engines-version@" pnpmLock) 2)) 0;
      in
        lib.lists.last (lib.strings.splitString "." version);

      # exmple line:
      # '@prisma/engines-version@5.15.0-29.12e25d8d06f6ea5a0252864dd9a03b1bb51f3022':
      "9" = pnpmLock: let
        version = builtins.elemAt (builtins.split "'" (builtins.elemAt (builtins.split "@prisma/engines-version@" pnpmLock) 2)) 0;
      in
        lib.lists.last (lib.strings.splitString "." version);
    };
    pnpmLock = builtins.readFile path;
    pnpmLockVersion = parsePnpmLockVersion pnpmLock;
    pnpmLockParser = pnpmLockParsers.${pnpmLockVersion};
    commit = pnpmLockParser pnpmLock;
  in
    commit;
  parseNpmLock = path: let
    packageLock = builtins.fromJSON (builtins.readFile path);
    version =
      if builtins.hasAttr "dependencies" packageLock
      then packageLock.dependencies.${"@prisma/engines-version"}.version
      else packageLock.packages.${"node_modules/@prisma/engines-version"}.version;
    commit = lib.lists.last (lib.strings.splitString "." version);
  in
    commit;
  parseYarnLock = path: let
    # find this line from yarn.lock:
    # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
    yarnLockParser1 = file: let
      versionLine =
        lib.lists.findFirst
        (line: builtins.length (lib.strings.splitString "@prisma/engines-version" line) >= 2)
        # else
        (throw ''
          nix-prisma-utils/yarnLockParser1: package @prisma/engines-version not found in lockfile ${path} .
          please make sure you have installed `@prisma/client`.
          if you have already installed `@prisma/client` and still see this, please report this to nix-prisma-utils.
        '')
        (lines file);
      # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
      # -> ["@prisma/engines-version@npm" "6" "3" "0-17" "acc0b9dd43eb689cbd20c9470515d719db10d0b0"]
      # -> acc0b9dd43eb689cbd20c9470515d719db10d0b0
      version = lib.lists.last (
        splitMultipleAndFilterEmpty [
          "\""
          ":"
          "."
        ]
        versionLine
      );
    in
      version;
    isYarnLockV1 = file:
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
      if isYarnLockV1 lockfile
      then yarnV1LockParser
      else let
        lockfileVersion = builtins.toString (readYAML path).__metadata.version;
      in
        yarnBerryLockParsers.${
          lockfileVersion
        } or (throw ''
          nix-prisma-utils: unknown lockfile version ${lockfileVersion}.
          please report this to nix-prisma-utils with your lockfile.
        '');
  in (parse lockfile);
  parseBunLock = path: let
    # HACK: nix doesn't support JSONC parsing, so currently doing
    # 1. remove whitespace and newline
    # 2. replace ",}" with "}"
    # 3. replace ",]" with "]"
    # to support JSON with trailing comma.
    # Keep in mind that this removes all whitespaces / tab / newline in the key / value
    # and doesn't support comments.
    fromJSONWithTrailingComma = jsonc:
      builtins.fromJSON (
        builtins.replaceStrings
        [
          ",}"
          ",]"
        ]
        [
          "}"
          "]"
        ]
        (
          builtins.replaceStrings
          [
            " "
            "\t"
            "\n"
          ]
          [
            ""
            ""
            ""
          ]
          jsonc
        )
      );
    bunLockParsers = {
      # example:
      # nu> open bun.lock | from json | get packages.@prisma/engines-version.0
      # @prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e
      "0" = bunLockParsers."1";
      "1" = lock:
        afterLastDot (
          builtins.elemAt (
            lock."packages"."@prisma/engines-version" or (throw ''
              nix-prisma-utils: lockfile parsing error: package @prisma/engines-version not found.
              please make sure that you have @prisma/client installed.
            '')
          )
          0
        );
    };
    lockfile = fromJSONWithTrailingComma (
      assert builtins.typeOf path == "path";
        builtins.readFile path
    );
    lockfileVersion = builtins.toString lockfile."lockfileVersion";
    parse =
      bunLockParsers.${
        lockfileVersion
      } or (throw ''
        nix-prisma-utils: Unsupported lockfile version: ${lockfileVersion}
        nix-prisma-utils currently supports bun.lock version of 0 and 1.
      '');
    commit = parse lockfile;
  in
    commit;
}
