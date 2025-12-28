{ lib, componentsToFetch, ... }:

{
  toExportStyle =
    attrset:
    "\n"
    + (lib.concatMapAttrsStringSep "\n" (name: value: "export ${name}=\"${value}\"") attrset)
    + "\n";
  mkEnv =
    package:
    builtins.listToAttrs (
      builtins.map (c: {
        name = c.variable;
        value = "${package}/${c.path}";
      }) componentsToFetch
    );
}
