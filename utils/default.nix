{ lib, callPackage }:
let
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

  # polyfill: the function in nixpkgs is implemented on Dec 6, 2024. replace this with one from pkgs.lib after 24.11 reaches EOL.
  concatMapAttrsStringSep =
    sep: f: attrs:
    lib.concatStringsSep sep (lib.attrValues (lib.mapAttrs f attrs));

  readYAML = callPackage ./readYAML.nix { };
  fromJSONWithTrailingCommas = callPackage ./fromJSONWithTrailingCommas.nix { };

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
{
  inherit
    lines
    _splitMultiple
    splitMultiple
    splitMultipleAndFilterEmpty
    afterLastDot
    concatMapAttrsStringSep
    readYAML
    fromJSONWithTrailingCommas
    toExportStyle
    ;
}
