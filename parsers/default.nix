{ callPackage, utils }:
{
  npmLock = callPackage ./npm-lock.nix { };
  yarnLock = callPackage ./yarn-lock.nix { inherit utils; };
  pnpmLock = callPackage ./pnpm-lock.nix { };
  bunLock = callPackage ./bun-lock.nix { inherit utils; };
}
