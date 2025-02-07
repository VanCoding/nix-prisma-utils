{
  # pkgs + lib
  utils,
  lib,
  stdenv,
  openssl,
  fetchurl,
  zlib,
  autoPatchelfHook,

  # info
  system,
  opensslVersion,
  binaryTargetBySystem,

  # hashes
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  introspection-engine-hash,
  schema-engine-hash,
  migration-engine-hash,
}:
commit:
if builtins.stringLength commit != 40 then
  throw "invalid commit: got ${commit}"
else
  let
    hostname = "binaries.prisma.sh";
    channel = "all_commits";
    binaryTarget = binaryTargetBySystem.${system};
    isDarwin = lib.strings.hasPrefix "darwin" binaryTarget;
    target = if isDarwin then binaryTarget else "${binaryTarget}-openssl-${opensslVersion}";
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
          name = if isDarwin then "libquery_engine.dylib.node" else "libquery_engine.so.node";
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
        file = fetchurl {
          name = "${baseUrl}/${commit}/${target}/${file.name}.gz";
          url = "${baseUrl}/${commit}/${target}/${file.name}.gz";
          hash = file.hash;
        };
      }
    ) files;
    unzipCommands = builtins.map (file: "gunzip -c ${file.file} > $out/${file.path}") downloadedFiles;
    package = stdenv.mkDerivation {
      pname = "prisma-bin";
      version = commit;
      nativeBuildInputs = [
        zlib
        openssl
        stdenv.cc.cc.lib
      ] ++ lib.optionals (!isDarwin) [ autoPatchelfHook ];
      phases = [
        "buildPhase"
        "postFixupHooks"
      ];
      buildPhase = ''
        mkdir -p $out/bin
        mkdir -p $out/lib
        ${lib.concatStringsSep "\n" unzipCommands}
        chmod +x $out/bin/*
      '';
    };
    env = builtins.listToAttrs (
      builtins.map (file: {
        name = file.variable;
        value = "${package}/${file.path}";
      }) files
    );
    shellHook = utils.toExportStyle env;
  in
  {
    inherit env package shellHook;
  }
