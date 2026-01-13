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
  openssl,
  opensslVersion,
  binaryTarget,
  hash,
  version,
  callPackage,
}:
let
  componentsToFetch = (callPackage ./components.nix { }).fromVersion version;
  isDarwin = lib.strings.hasPrefix "darwin" binaryTarget;
  target = if isDarwin then binaryTarget else "${binaryTarget}-openssl-${opensslVersion}";
  toUrl = url: "https://binaries.prisma.sh/all_commits/${version.commit}/${target}/${url}";
  envFuncs = callPackage ./env.nix {
    inherit componentsToFetch;
  };
  inherit (envFuncs) toExportStyle mkEnv;
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
            echo '[nix-prisma-utils] fetching ${toUrl (component.getFileName isDarwin)} to $out/${component.path}'
            curl "${toUrl (component.getFileName isDarwin)}" -L | gunzip > $out/${component.path}
          '') componentsToFetch
        )}
      '';
  package = stdenv.mkDerivation {
    pname = "prisma-bin";
    src = deps;
    version = version.commit;
    nativeBuildInputs = [
      zlib
      openssl
      stdenv.cc.cc.lib
    ]
    ++ lib.optionals (!isDarwin) [ autoPatchelfHook ];
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

  env = mkEnv package;
in
{
  inherit package env;
  shellHook = toExportStyle env;
}
