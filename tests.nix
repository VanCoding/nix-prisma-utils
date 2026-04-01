{
  pkgs,
  writeShellApplication,
  prisma-factory,
  fetcherMode, # legacy or new
  nodejs,
  pnpm,
  yarn-v1,
  yarn-berry,
  bun,
}:
let
  hashesBySystem =
    if fetcherMode == "new" then
      {
        x86_64-linux.hash = "sha256-R9PG286KQTbzF0r/PPcShUkMiYam2prRh/JICjmhCZA=";
        aarch64-linux.hash = "sha256-RvloEj41YTf+SwaHLqBlJ5Rpu00UPENprsQRHam3zic=";
        x86_64-darwin.hash = "sha256-z1VypBp/JN4qipqTFDmVPb/H1I+TdQVcUU4EIsIPQJ8=";
        aarch64-darwin.hash = "sha256-LxpKAAjnRn8eH7h9trOOYKf0WcY+aHGrzzVGW2aViek=";
      }
    else if fetcherMode == "legacy" then
      {
        x86_64-linux = {
          prisma-fmt-hash = "sha256-4zsJv0PW8FkGfiiv/9g0y5xWNjmRWD8Q2l2blSSBY3s=";
          query-engine-hash = "sha256-6ILWB6ZmK4ac6SgAtqCkZKHbQANmcqpWO92U8CfkFzw=";
          libquery-engine-hash = "sha256-n9IimBruqpDJStlEbCJ8nsk8L9dDW95ug+gz9DHS1Lc=";
          schema-engine-hash = "sha256-j38xSXOBwAjIdIpbSTkFJijby6OGWCoAx+xZyms/34Q=";
        };
        aarch64-linux = {
          prisma-fmt-hash = "sha256-gqbgN9pZxzZEi6cBicUfH7qqlXWM+z28sGVuW/wKHb8=";
          query-engine-hash = "sha256-q1HVbRtWhF3J5ScETrwvGisS8fXA27nryTvqFb+XIuo=";
          libquery-engine-hash = "sha256-oalG9QKuxURtdgs5DgJZZtyWMz3ZpywHlov+d1ct2vA=";
          schema-engine-hash = "sha256-5bp8iiq6kc9c37G8dNKVHKWJHvaxFaetR4DOR/0/eWs=";
        };
        x86_64-darwin = {
          prisma-fmt-hash = "sha256-Z0AIuCRW0GEd6QRiyYdVVS1Zb6d1aRH+jUE0JNXFgiQ=";
          query-engine-hash = "sha256-TjJp72T9nmJcIrMLUIpnapzNlRyVpGp/jGaSuJ0nUDI=";
          libquery-engine-hash = "sha256-cerpi9y9w6Fn1meXuj2VDRdIQz/MZvrQ7LZKa0Z70yM=";
          schema-engine-hash = "sha256-tfR5B8s5GfmeE1kFlmYyxS7Kw1ELShBKsf+i5MmS+/o=";
        };
        aarch64-darwin = {
          prisma-fmt-hash = "sha256-UPig7U2zXOccalIUE0j07xJdmqAUJ7cpXFTo+2Gbsc8=";
          query-engine-hash = "sha256-ihP1BEAvXQ+5XXHEXCYAVTnuETpfxmdtsIGRTljKtS0=";
          libquery-engine-hash = "sha256-4T63O+OyoEIJ0TLKoOoil06whd+41QxiXXg+0cgpX/8=";
          schema-engine-hash = "sha256-+O4IelHbZt4X+6UWol8TpL+BBDTS5JT+0hQR7ELVmZc=";
        };
      }
    else
      let
        args = {
          usePrismaFromPkgs = true;
          prismaEnginesGitHubHash = "sha256-p198o8ON5mGPCxK+gE0mW+JVyQlNsCsqwa8D4MNBkpA=";
          prismaEnginesCargoHash = "sha256-bNl04GoxLX+B8dPgqWL/VarreBVebjwNDwQjtQcJnsg=";
        };
      in
      {
        x86_64-linux = args;
        aarch64-linux = args;
        x86_64-darwin = args;
        aarch64-darwin = args;
      };
  test-npm =
    let
      prisma =
        (pkgs.callPackage prisma-factory hashesBySystem.${pkgs.system}).fromNpmLock
          ./npm/package-lock.json;
    in
    writeShellApplication {
      name = "test-npm";
      runtimeInputs = [ nodejs ];
      runtimeEnv = prisma.env;
      text = ''
        echo "testing npm"
        cd npm
        npm ci
        ./node_modules/.bin/prisma generate
      '';
    };
  makeTestPnpm =
    lockfilePath: suffix:
    let
      prisma = (pkgs.callPackage prisma-factory hashesBySystem.${pkgs.system}).fromPnpmLock lockfilePath;
    in
    writeShellApplication {
      name = "test-pnpm${suffix}";
      runtimeInputs = [ pnpm ];
      runtimeEnv = prisma.env;
      text = ''
        echo "testing pnpm"
        cd pnpm
        pnpm install
        ./node_modules/.bin/prisma generate
      '';
    };
  test-pnpm = makeTestPnpm ./pnpm/pnpm-lock.yaml "";
  test-pnpm-prisma-6 = makeTestPnpm ./pnpm-prisma-6/pnpm-lock.yaml "-prisma-6";
  test-bun =
    let
      prisma = (pkgs.callPackage prisma-factory hashesBySystem.${pkgs.system}).fromBunLock ./bun/bun.lock;
    in
    writeShellApplication {
      name = "test-bun";
      runtimeInputs = [ bun ];
      runtimeEnv = prisma.env;
      text = ''
        echo "testing bun"
        cd bun
        bun install
        bunx prisma generate
      '';
    };
  test-yarn-v1 =
    let
      prisma =
        (pkgs.callPackage prisma-factory hashesBySystem.${pkgs.system}).fromYarnLock
          ./yarn-v1/yarn.lock;
    in
    writeShellApplication {
      name = "test-yarn-v1";
      runtimeInputs = [ yarn-v1 ];
      runtimeEnv = prisma.env;
      text = ''
        echo "testing yarn v1"
        cd yarn-v1
        yarn-v1 install
        yarn-v1 prisma generate
      '';
    };
  test-yarn-berry =
    let
      prisma =
        (pkgs.callPackage prisma-factory hashesBySystem.${pkgs.system}).fromYarnLock
          ./yarn-berry/yarn.lock;
    in
    writeShellApplication {
      name = "test-yarn-berry";
      runtimeInputs = [ yarn-berry ];
      runtimeEnv = prisma.env;
      text = ''
        echo "testing yarn berry"
        cd yarn-berry
        yarn-berry install
        yarn-berry prisma generate
      '';
    };
in
if fetcherMode == "fromPkgs" then
  {
    # Using the derivation from nixpkgs only works for versions
    # of prisma such that the derivation correctly builds it.
    # That is not the case of prisma 5.1.1 used in the other tests,
    # therefore we test prisma 6 (this is described in the docs).
    "test-pnpm-prisma-6-${fetcherMode}" = test-pnpm-prisma-6;
  }
else
  {
    "test-npm-${fetcherMode}" = test-npm;
    "test-pnpm-${fetcherMode}" = test-pnpm;
    "test-bun-${fetcherMode}" = test-bun;
    "test-yarn-v1-${fetcherMode}" = test-yarn-v1;
    "test-yarn-berry-${fetcherMode}" = test-yarn-berry;
  }
