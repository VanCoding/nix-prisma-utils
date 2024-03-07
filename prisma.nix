{
  nixpkgs,
  openssl3 ? true,
  openssl ? nixpkgs.openssl,
  introspection-engine-hash ? null,
  migration-engine-hash ? null,
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  schema-engine-hash ? null,
}:
rec {
  fromCommit =
    commit:
    let
      hostname = "binaries.prisma.sh";
      channel = "all_commits";
      target = "debian-openssl-${if openssl3 then "3.0.x" else "1.1.x"}";
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
      pnpmLock = builtins.readFile path;
      splitCharacter = if nixpkgs.lib.strings.hasPrefix "lockfileVersion: 5" pnpmLock then "/" else "@";
      version = builtins.elemAt (builtins.split ":" (
        builtins.elemAt (builtins.split ("@prisma/engines-version" + splitCharacter) pnpmLock) 2
      )) 0;
      commit = nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." version);
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
    builtins.trace commit (fromCommit commit);
}
