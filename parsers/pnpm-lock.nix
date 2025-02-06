# Type
# path -> string (commit)
{ lib }:
path:
let
  pnpmLock = builtins.readFile path;
  lockfileVersion =
    if lib.strings.hasPrefix "lockfileVersion: 5" pnpmLock then
      "5"
    else if lib.strings.hasPrefix "lockfileVersion: '6" pnpmLock then
      "6"
    else if lib.strings.hasPrefix "lockfileVersion: '9" pnpmLock then
      "9"
    else
      throw ''
        nix-prisma-utils: unknown pnpm lockfile version. please report this to nix-prisma-utils with your lockfile.
      '';
  pnpmLockParsers = {
    # example line:
    # /@prisma/engines-version/5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
    "5" =
      pnpmLock:
      let
        version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split "@prisma/engines-version/" pnpmLock) 2)) 0;
      in
      lib.lists.last (lib.strings.splitString "." version);

    # example line:
    # /@prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
    "6" =
      pnpmLock:
      let
        version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split "@prisma/engines-version@" pnpmLock) 2)) 0;
      in
      lib.lists.last (lib.strings.splitString "." version);

    # exmple line:
    # '@prisma/engines-version@5.15.0-29.12e25d8d06f6ea5a0252864dd9a03b1bb51f3022':
    "9" =
      pnpmLock:
      let
        version = builtins.elemAt (builtins.split "'" (builtins.elemAt (builtins.split "@prisma/engines-version@" pnpmLock) 2)) 0;
      in
      lib.lists.last (lib.strings.splitString "." version);
  };
  pnpmLockParser = pnpmLockParsers.${lockfileVersion};
  commit = pnpmLockParser pnpmLock;
in
commit
