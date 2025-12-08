{ lib, ... }:
let
  isv7 =
    version:
    version.majorVersion >= 7
    || (
      version.majorVersion == 6
      && version.minorVersion >= 19
      && lib.strings.hasInfix "next" version.preReleaseVersion
    );
  components = [
    {
      name = "migration-engine";
      getFileName = isDarwin: "migration-engine.gz";
      path = "bin/migration-engine";
      variable = "PRISMA_MIGRATION_ENGINE_BINARY";
      isIncluded = version: false;
    }
    {
      name = "prisma-fmt";
      getFileName = isDarwin: "prisma-fmt.gz";
      path = "bin/prisma-fmt";
      variable = "PRISMA_FMT_BINARY";
      isIncluded = version: true;
    }
    {
      name = "schema-engine";
      getFileName = isDarwin: "schema-engine.gz";
      path = "bin/schema-engine";
      variable = "PRISMA_SCHEMA_ENGINE_BINARY";
      isIncluded = version: true;
    }
    {
      name = "query-engine";
      getFileName = isDarwin: "query-engine.gz";
      path = "bin/query-engine";
      variable = "PRISMA_QUERY_ENGINE_BINARY";
      isIncluded = version: !(isv7 version);
    }
    {
      name = "libquery-engine";
      getFileName =
        isDarwin: if isDarwin then "libquery_engine.dylib.node.gz" else "libquery_engine.so.node.gz";
      path = "lib/libquery_engine.node";
      variable = "PRISMA_QUERY_ENGINE_LIBRARY";
      isIncluded = version: !(isv7 version);
    }
    {
      name = "introspection-engine";
      getFileName = isDarwin: "introspection-engine.gz";
      path = "bin/introspection-engine";
      variable = "PRISMA_INTROSPECTION_ENGINE_BINARY";
      isIncluded = version: false;
    }
  ];
in
{
  fromVersion = version: lib.filter (component: component.isIncluded version) components;
  fromHashes = hashes: lib.filter (component: ((hashes."${component.name}-hash") != null)) components;
}
