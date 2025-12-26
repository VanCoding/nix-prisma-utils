hashes@{
  # dependencies
  lib,
  fetchurl,
  stdenv,
  zlib,
  autoPatchelfHook,
  # variables
  openssl,
  opensslVersion,
  binaryTarget,
  # = hashes
  prisma-fmt-hash,
  query-engine-hash,
  libquery-engine-hash,
  introspection-engine-hash,
  migration-engine-hash,
  schema-engine-hash,
  version,
  callPackage,
}:
let
  hostname = "binaries.prisma.sh";
  channel = "all_commits";
  isDarwin = lib.strings.hasPrefix "darwin" binaryTarget;
  target = if isDarwin then binaryTarget else "${binaryTarget}-openssl-${opensslVersion}";
  baseUrl = "https://${hostname}/${channel}";
  files = (callPackage ./components.nix { }).fromHashes {
    inherit
      prisma-fmt-hash
      query-engine-hash
      libquery-engine-hash
      introspection-engine-hash
      migration-engine-hash
      schema-engine-hash
      ;
  };
  downloadedFiles = builtins.map (
    file:
    file
    // {
      file = fetchurl {
        name = "${baseUrl}/${version.commit}/${target}/${file.getFileName isDarwin}";
        url = "${baseUrl}/${version.commit}/${target}/${file.getFileName isDarwin}";
        hash = hashes."${file.name}-hash";
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
    version = version.commit;
    nativeBuildInputs = [
      zlib
      openssl
      stdenv.cc.cc.lib
    ]
    ++ lib.optionals (!isDarwin) [ autoPatchelfHook ];
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
