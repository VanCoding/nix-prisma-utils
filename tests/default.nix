{
  pkgs,
  prisma-factory,
  yarn-v1,
  yarn-berry,
}:
(pkgs.callPackages ./prisma-generate.nix {
  fetcherMode = "legacy";
  inherit
    pkgs
    prisma-factory
    yarn-v1
    yarn-berry
    ;
})
// (pkgs.callPackages ./prisma-generate.nix {
  fetcherMode = "new";
  inherit
    pkgs
    prisma-factory
    yarn-v1
    yarn-berry
    ;
})
// pkgs.callPackages ./fetcher-regression.nix {
  inherit prisma-factory;
}
