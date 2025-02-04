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
      # polyfill: the function in nixpkgs is implemented on Dec 6, 2024. replace this with one from pkgs.lib after 24.11 reaches EOL.
      concatMapAttrsStringSep =
        let
          inherit (nixpkgs) lib;
        in
        sep: f: attrs:
        lib.concatStringsSep sep (lib.attrValues (lib.mapAttrs f attrs));

      hostname = "binaries.prisma.sh";
      channel = "all_commits";
      binaryTarget = binaryTargetBySystem.${nixpkgs.system};
      isDarwin = nixpkgs.lib.strings.hasPrefix "darwin" binaryTarget;
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
          file = nixpkgs.fetchurl {
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
      package = nixpkgs.stdenv.mkDerivation {
        pname = "prisma-bin";
        version = commit;
        nativeBuildInputs = [
          nixpkgs.zlib
          openssl
          nixpkgs.stdenv.cc.cc.lib
        ] ++ nixpkgs.lib.optionals (!isDarwin) [ nixpkgs.autoPatchelfHook ];
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
      env = mkEnv package;
      shellHook = toExportStyle env;
    };
  # example:
  # a.b123c.d.e12345
  # => e12345
  afterLastDot = text: nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." text);
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
          let
            version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split ("@prisma/engines-version/") pnpmLock) 2)) 0;
          in
          nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." version);

        # example line:
        # /@prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
        "6" =
          pnpmLock:
          let
            version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split ("@prisma/engines-version@") pnpmLock) 2)) 0;
          in
          nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." version);

        # exmple line:
        # '@prisma/engines-version@5.15.0-29.12e25d8d06f6ea5a0252864dd9a03b1bb51f3022':
        "9" =
          pnpmLock:
          let
            version = builtins.elemAt (builtins.split "'" (builtins.elemAt (builtins.split ("@prisma/engines-version@") pnpmLock) 2)) 0;
          in
          nixpkgs.lib.lists.last (nixpkgs.lib.strings.splitString "." version);
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
  fromBunLock =
    path:
    let
      # HACK: nix doesn't support JSONC parsing, so currently doing
      # 1. remove whitespace and newline
      # 2. replace ",}" with "}"
      # 3. replace ",]" with "]"
      # to support JSON with trailing comma.
      # Keep in mind that this removes all whitespaces / tab / newline in the key / value
      # and doesn't support comments.
      fromJSONWithTrailingComma =
        jsonc:
        builtins.fromJSON (
          builtins.replaceStrings
            [
              ",}"
              ",]"
            ]
            [
              "}"
              "]"
            ]
            (
              builtins.replaceStrings
                [
                  " "
                  "\t"
                  "\n"
                ]
                [
                  ""
                  ""
                  ""
                ]
                jsonc
            )
        );
      bunLockParsers = {
        # example:
        # nu> open bun.lock | from json | get packages.@prisma/engines-version.0
        # @prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e
        "0" = bunLockParsers."1";
        "1" =
          lock:
          afterLastDot (
            builtins.elemAt (lock."packages"."@prisma/engines-version" or (throw ''
              nix-prisma-utils: lockfile parsing error: package @prisma/engines-version not found.
              please make sure that you have @prisma/client installed.
            '')
            ) 0
          );
      };
      lockfile = fromJSONWithTrailingComma (
        assert builtins.typeOf path == "path";
        builtins.readFile path
      );
      lockfileVersion = builtins.toString lockfile."lockfileVersion";
      parse =
        bunLockParsers.${lockfileVersion} or (throw ''
          nix-prisma-utils: Unsupported lockfile version: ${lockfileVersion}
          nix-prisma-utils currently supports bun.lock version of 0 and 1.
        '');
      commit = parse lockfile;
    in
    fromCommit commit;
}
