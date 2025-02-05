{
  nixpkgs ? null,
  # if both are set, prefer pkgs over nixpkgs
  pkgs ? nixpkgs,
  opensslVersion ? "3.0.x", # can be 3.0.x, 1.1.x or 1.0.x
  openssl ? pkgs.openssl, # the openssl package to use
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
let
  inherit (pkgs) lib;
  lines = s: lib.strings.splitString "\n" s;

  # example:
  # splitMultiple ["|" "," "-"] "a-|b,c-d"
  # -> ["a" "" "b" "c" "d"]
  splitMultiple = delims: s: _splitMultiple delims [ s ];
  # example:
  # _splitMultiple ["|" "," "-"] ["a-|b,c-d"]
  # -> ["a" "" "b" "c" "d"]
  _splitMultiple =
    delims: list:
    if builtins.length delims == 0 then
      list
    else
      let
        splitStr = map (str: lib.strings.splitString (builtins.elemAt delims 0) str) list;
      in
      _splitMultiple (lib.drop 1 delims) (lib.lists.concatLists splitStr);
  splitMultipleAndFilterEmpty = delims: s: builtins.filter (str: str != "") (splitMultiple delims s);
  # example:
  # a.b123c.d.e12345
  # => e12345
  afterLastDot = text: lib.lists.last (lib.strings.splitString "." text);

  readYAML = pkgs.callPackage ./lib/readYAML.nix { };
  # polyfill: the function in nixpkgs is implemented on Dec 6, 2024. replace this with one from pkgs.lib after 24.11 reaches EOL.
  concatMapAttrsStringSep =
    let
      inherit (pkgs) lib;
    in
    sep: f: attrs:
    lib.concatStringsSep sep (lib.attrValues (lib.mapAttrs f attrs));

in
pkgs.lib.warnIf (nixpkgs != null)
  ''
    `nixpkgs` argument in nix-prisma-utils is deprecated. please replace it with `pkgs`.
    examples:
      if your code has `inherit nixpkgs;`, replace it with `pkgs = nixpkgs;`.
      if your code has `nixpkgs = pkgs;`, replace it with `pkgs = pkgs;` or `inherit pkgs;`.
  ''
  rec {
    fromCommit =
      commit:
      if builtins.stringLength commit != 40 then
        throw "nvalid commit: got ${commit}"
      else
        let
          hostname = "binaries.prisma.sh";
          channel = "all_commits";
          binaryTarget = binaryTargetBySystem.${pkgs.system};
          isDarwin = pkgs.lib.strings.hasPrefix "darwin" binaryTarget;
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
              file = pkgs.fetchurl {
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
          package = pkgs.stdenv.mkDerivation {
            pname = "prisma-bin";
            version = commit;
            nativeBuildInputs = [
              pkgs.zlib
              openssl
              pkgs.stdenv.cc.cc.lib
            ] ++ pkgs.lib.optionals (!isDarwin) [ pkgs.autoPatchelfHook ];
            phases = [
              "buildPhase"
              "postFixupHooks"
            ];
            buildPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/lib
              ${pkgs.lib.concatStringsSep "\n" unzipCommands}
              chmod +x $out/bin/*
            '';
          };
          env = mkEnv package;
          shellHook = toExportStyle env;
        };
    fromPnpmLock =
      path:
      let
        textAfter = keyword: text: builtins.elemAt (builtins.split keyword text) 1;
        textBefore = keyword: text: builtins.elemAt (builtins.split keyword text) 0;
        parsePnpmLockVersion =
          pnpmLock:
          if pkgs.lib.strings.hasPrefix "lockfileVersion: 5" pnpmLock then
            "5"
          else if pkgs.lib.strings.hasPrefix "lockfileVersion: '6" pnpmLock then
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
            pkgs.lib.lists.last (pkgs.lib.strings.splitString "." version);

          # example line:
          # /@prisma/engines-version@5.1.1-1.6a3747c37ff169c90047725a05a6ef02e32ac97e:
          "6" =
            pnpmLock:
            let
              version = builtins.elemAt (builtins.split ":" (builtins.elemAt (builtins.split ("@prisma/engines-version@") pnpmLock) 2)) 0;
            in
            pkgs.lib.lists.last (pkgs.lib.strings.splitString "." version);

          # exmple line:
          # '@prisma/engines-version@5.15.0-29.12e25d8d06f6ea5a0252864dd9a03b1bb51f3022':
          "9" =
            pnpmLock:
            let
              version = builtins.elemAt (builtins.split "'" (builtins.elemAt (builtins.split ("@prisma/engines-version@") pnpmLock) 2)) 0;
            in
            pkgs.lib.lists.last (pkgs.lib.strings.splitString "." version);
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
        commit = pkgs.lib.lists.last (pkgs.lib.strings.splitString "." version);
      in
      fromCommit commit;
    fromYarnLock =
      path:
      let
        # find this line from yarn.lock:
        # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
        yarnLockParser1 =
          file:
          let
            versionLine =
              lib.lists.findFirst
                (line: builtins.length (lib.strings.splitString "@prisma/engines-version" line) >= 2)
                # else
                (throw ''
                  nix-prisma-utils/yarnLockParser1: package @prisma/engines-version not found in lockfile ${path} .
                  please make sure you have installed `@prisma/client`.
                  if you have already installed `@prisma/client` and still see this, please report this to nix-prisma-utils.
                '')
                (lines file);
            # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
            # -> ["@prisma/engines-version@npm" "6" "3" "0-17" "acc0b9dd43eb689cbd20c9470515d719db10d0b0"]
            # -> acc0b9dd43eb689cbd20c9470515d719db10d0b0
            version = lib.lists.last (
              splitMultipleAndFilterEmpty [
                "\""
                ":"
                "."
              ] versionLine
            );
          in
          version;
        isYarnLockV1 =
          file:
          lib.lists.any (line: lib.strings.trim line == "# yarn lockfile v1") (
            lib.strings.splitString "\n" file
          );
        # example line:
        # "@prisma/engines-version@6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
        yarnV1LockParser = yarnLockParser1;
        # example line:
        # "@prisma/engines-version@npm:6.3.0-17.acc0b9dd43eb689cbd20c9470515d719db10d0b0":
        yarnBerryLockParsers = {
          "8" = yarnLockParser1;
        };

        lockfile = builtins.readFile path;
        parse =
          if isYarnLockV1 lockfile then
            yarnV1LockParser
          else
            let
              lockfileVersion = builtins.toString (readYAML path).__metadata.version;
            in
            yarnBerryLockParsers.${lockfileVersion} or (throw ''
              nix-prisma-utils: unknown lockfile version ${lockfileVersion}.
              please report this to nix-prisma-utils with your lockfile.
            '');
      in
      fromCommit (parse lockfile);
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
