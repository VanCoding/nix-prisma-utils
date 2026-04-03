{
  outputs = inputs: {
    lib = {
      prisma-factory = import ./prisma.nix;
    };
  };
}
