# HACK: nix doesn't support JSONC parsing, so currently doing
# 1. remove whitespace and newline
# 2. replace ",}" with "}"
# 3. replace ",]" with "]"
# to support JSON with trailing comma.
# Keep in mind that this removes all whitespaces / tab / newline in the key / value
# and doesn't support comments.
{ }:
jsonc:
builtins.fromJSON (
  builtins.replaceStrings [ ",}" ",]" ] [ "}" "]" ] (
    builtins.replaceStrings [ " " "\t" "\n" ] [ "" "" "" ] jsonc
  )
)
