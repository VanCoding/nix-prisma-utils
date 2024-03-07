{ nixpkgs, prisma-factory }:
with nixpkgs;
let
  test-npm =
    let
      prisma =
        (prisma-factory {
          inherit nixpkgs;
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s=";
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        }).fromNpmLock
          ./npm/package-lock.json;
    in
    writeShellApplication {
      name = "test-npm";
      text = ''
        echo "testing npm"
        ${prisma.shellHook}
        cd npm
        npm ci
        ./node_modules/.bin/prisma generate
      '';
    };
  test-pnpm =
    let
      prisma =
        (prisma-factory {
          inherit nixpkgs;
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s=";
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        }).fromPnpmLock
          ./pnpm/pnpm-lock.yaml;
    in
    writeShellApplication {
      name = "test-pnpm";
      text = ''
        echo "testing pnpm"
        ${prisma.shellHook}
        cd pnpm
        pnpm install
        ./node_modules/.bin/prisma generate
      '';
    };
  test-all = writeShellApplication {
    name = "test";
    runtimeInputs = [
      test-pnpm
      test-npm
    ];
    text = ''
      test-npm
      test-pnpm
    '';
  };
in
{
  inherit test-npm test-pnpm test-all;
}
