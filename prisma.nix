{
  nixpkgs,
  opensslVersion ? "3.0.x", # can be 3.0.x, 1.1.x or 1.0.x
  openssl ? nixpkgs.openssl, # the openssl package to use
  introspection-engine-hash ? null,
  migration-engine-hash ? null,
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  schema-engine-hash ? null,
  binaryTargetBySystem ? {
    x86_64-linux = "debian";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin";
    aarch64-darwin = "darwin-arm64";
  },
}:
rec {
  fromCommit =
    commit:
    let
      hostname = "binaries.prisma.sh";
      channel = "all_commits";
      binaryTarget = binaryTargetBySystem.${nixpkgs.system};
      target = "${binaryTarget}-openssl-${opensslVersion}";
      baseUrl = "https://${hostname}/${channel}";
      files =
        [
          {
            name = "prisma-fmt";
            hash = prisma-fmt-hash;
            path = "bin/prisma-fmt";
            variable = "PRISMA_FMT_BINARY";
          }
          {
            name = "query-engine";
            hash = query-engine-hash;
            path = "bin/query-engine";
            variable = "PRISMA_QUERY_ENGINE_BINARY";
          }
          {
            name = "libquery_engine.so.node";
            hash = libquery-engine-hash;
            path = "lib/libquery_engine.node";
            variable = "PRISMA_QUERY_ENGINE_LIBRARY";
          }
        ]
        ++ (
          if introspection-engine-hash == null then
            [ ]
          else
            [
              {
                name = "introspection-engine";
                hash = introspection-engine-hash;
                path = "bin/introspection-engine";
                variable = "PRISMA_INTROSPECTION_ENGINE_BINARY";
              }
            ]
        )
        ++ (
          if migration-engine-hash == null then
            [ ]
          else
            [
              {
                name = "migration-engine";
                hash = migration-engine-hash;
                path = "bin/migration-engine";
                variable = "PRISMA_MIGRATION_ENGINE_BINARY";
              }
            ]
        )
        ++ (
          if schema-engine-hash == null then
            [ ]
          else
            [
              {
                name = "schema-engine";
                hash = schema-engine-hash;
                path = "bin/schema-engine";
                variable = "PRISMA_SCHEMA_ENGINE_BINARY";
              }
            ]
        );
      downloadedFiles = builtins.map (
        file:
        file
        // {
          file = nixpkgs.fetchurl {
            name = "${baseUrl}/${commit}/${target}/${file.name}.gz";
            url = "${baseUrl}/${commit}/${target}/${file.name}.gz";
            hash = file.hash;
          };
        }
      ) files;
      unzipCommands = builtins.map (file: "gunzip -c ${file.file} > $out/${file.path}") downloadedFiles;
      exportCommands =
        package: builtins.map (file: "export ${file.variable}=${package}/${file.path}") files;
    in
    rec {
      package = nixpkgs.stdenv.mkDerivation {
        pname = "prisma-bin";
        version = commit;
        nativeBuildInputs = [
          nixpkgs.autoPatchelfHook
          nixpkgs.zlib
          openssl
          nixpkgs.stdenv.cc.cc.lib
        ];
        phases = [
          "buildPhase"
          "postFixupHooks"
        ];
        buildPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib
          ${nixpkgs.lib.concatStringsSep "\n" unzipCommands}
          chmod +x $out/bin/*
        '';
      };
      shellHook = nixpkgs.lib.concatStringsSep "\n" (exportCommands package);
    };
  fromPnpmLock =
    path:
    let
      textAfter = keyword: text: builtins.elemAt (builtins.split keyword text) 1;
      textBefore = keyword: text: builtins.elemAt (builtins.split keyword text) 0;
      parsePnpmLockVersion =
        pnpmLock:
        if nixpkgs.lib.strings.hasPrefix "lockfileVersion: 5" pnpmLock then
          "5"
        else if nixpkgs.lib.strings.hasPrefix "lockfileVersion: '6" pnpmLock then
          "6"
        else
          "9";
      pnpmLockParsers = {
        # example line:
        # /@prisma/engines-version/5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
        "5" =
          pnpmLock:
          builtins.elemAt (builtins.match ".*@prisma/engines-version/.*\\.([0-9a-f]{40}):.*" pnpmLock) 0;

        # example line:
        # /@prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
        "6" =
          pnpmLock:
          builtins.elemAt (builtins.match ".*@prisma/engines-version@.*\\.([0-9a-f]{40}):.*" pnpmLock) 0;

        # exmple line:
        # '@prisma/engines-version@5.15.0-29.12e25d8d06f6ea5a0252864dd9a03b1bb51f3022':
        "9" =
          pnpmLock:
          builtins.elemAt (builtins.match ".*@prisma/engines-version@.*\\.([0-9a-f]{40})'.*" pnpmLock) 0;
      };
      pnpmLock = builtins.readFile path;
      pnpmLockVersion = parsePnpmLockVersion pnpmLock;
      pnpmLockParser = pnpmLockParsers.${pnpmLockVersion};
      commit = pnpmLockParser pnpmLock;
    in
    fromCommit commit;
  fromNpmLock =
    path:
    let
      packageLock = builtins.fromJSON (builtins.readFile path);
      version =
        if builtins.hasAttr "dependencies" packageLock then
          packageLock.dependencies.${"@prisma/engines-version"}.version
        else
          packageLock.packages.${"node_modules/@prisma/engines-version"}.version;
      commit = nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." version);
    in
    fromCommit commit;
}
