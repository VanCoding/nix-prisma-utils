{
  perSystem =
    { pkgs, config, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs.nodejs_24
          pkgs.pnpm
          pkgs.bun
          pkgs.stdenv.cc.cc.lib
          config.treefmt.build.wrapper
        ];
      };
    };
}
