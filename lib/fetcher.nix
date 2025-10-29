{
  lib,
  stdenv,
  zlib,
  curl,
  cacert,
  autoPatchelfHook,
  runCommand,
  gzip,
  # variables
  commit,
  openssl,
  opensslVersion,
  binaryTarget,
  hash,
  components,
}:
let
  componentsToFetch =
    if components != null then
      components
    else
      [
        {
          url = "prisma-fmt.gz";
          path = "bin/prisma-fmt";
          env = "PRISMA_FMT_BINARY";
        }
        {
          url = "query-engine.gz";
          path = "bin/query-engine";
          env = "PRISMA_QUERY_ENGINE_BINARY";
        }
        {
          url = if isDarwin then "libquery_engine.dylib.node.gz" else "libquery_engine.so.node.gz";
          path = "lib/libquery_engine.node";
          env = "PRISMA_QUERY_ENGINE_LIBRARY";
        }
        {
          url = "schema-engine.gz";
          path = "bin/schema-engine";
          env = "PRISMA_SCHEMA_ENGINE_BINARY";
        }
      ];
  isDarwin = lib.strings.hasPrefix "darwin" binaryTarget;
  target = if isDarwin then binaryTarget else "${binaryTarget}-openssl-${opensslVersion}";
  toUrl = url: "https://binaries.prisma.sh/all_commits/${commit}/${target}/${url}";
  deps =
    runCommand "prisma-deps-bin"
      {
        nativeBuildInputs = [
          curl
          cacert
          gzip
        ];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = hash;
      }
      ''
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        export CURL_CA_BUNDLE=$SSL_CERT_FILE
        mkdir -p $out $out/lib $out/bin
        ${lib.concatLines (
          map (component: ''
            curl "${toUrl component.url}" -L | gunzip > $out/${component.path}
          '') componentsToFetch
        )}
      '';
  package = stdenv.mkDerivation {
    pname = "prisma-bin";
    src = deps;
    version = commit;
    nativeBuildInputs = [
      zlib
      openssl
      stdenv.cc.cc.lib
    ] ++ lib.optionals (!isDarwin) [ autoPatchelfHook ];
    phases = [
      "installPhase"
      "postFixupHooks"
    ];
    installPhase = ''
      mkdir -p $out
      cp -r $src/. $out/
      mkdir -p $out/bin
      chmod -R u+w $out
      find $out/bin -type f -exec chmod +x {} +
    '';
  };
  toExportStyle =
    attrset:
    "\n"
    + (lib.concatMapAttrsStringSep "\n" (name: value: "export ${name}=\"${value}\"") attrset)
    + "\n";
  mkEnv =
    package:
    builtins.listToAttrs (
      builtins.map (c: {
        name = c.env;
        value = "${package}/${c.path}";
      }) componentsToFetch
    );
  env = mkEnv package;
in
{
  inherit package env;
  shellHook = toExportStyle env;
}
