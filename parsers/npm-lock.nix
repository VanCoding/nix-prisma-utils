{ lib }:
path:
let
  packageLock = builtins.fromJSON (builtins.readFile path);
  version =
    if builtins.hasAttr "dependencies" packageLock then
      packageLock.dependencies.${"@prisma/engines-version"}.version
    else
      packageLock.packages.${"node_modules/@prisma/engines-version"}.version;
  commit = lib.lists.last (lib.strings.splitString "." version);
in
commit
