{
  # dependencies
  lib,
  fetchurl,
  stdenv,
  zlib,
  autoPatchelfHook,
  # variables
  openssl,
  commit,
  opensslVersion,
  binaryTarget,
  isv7,
  # = hashes
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  introspection-engine-hash,
  migration-engine-hash,
  schema-engine-hash,
}:
let
  hostname = "binaries.prisma.sh";
  channel = "all_commits";
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
    ]
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
    )
    ++ lib.optionals (!isv7) [
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

  mkEnv =
    package:
    builtins.listToAttrs (
      builtins.map (file: {
        name = file.variable;
        value = "${package}/${file.path}";
      }) files
    );
  # polyfill: the function in nixpkgs is implemented on Dec 6, 2024. replace this with one from pkgs.lib after 24.11 reaches EOL.
  concatMapAttrsStringSep =
    sep: f: attrs:
    lib.concatStringsSep sep (lib.attrValues (lib.mapAttrs f attrs));
  /**
    This function converts attrset to bash export style.
    return value contains leading and trailing newlines.

    # Example
    ```nix
    toExportStyle { foo = "bar"; baz = "abc"; }
    =>
    ''
      export foo="bar"
      export baz="abc"
    ''
    ```

    # Type
    toExportStyle :: Attrset<String> -> String
  */
  toExportStyle =
    attrset:
    "\n" + (concatMapAttrsStringSep "\n" (name: value: "export ${name}=\"${value}\"") attrset) + "\n";
in
rec {
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
  env = mkEnv package;
  shellHook = toExportStyle env;
}
