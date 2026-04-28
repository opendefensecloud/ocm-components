{
  description = "ocm-components development flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    dev-kit = {
      url = "github:opendefensecloud/dev-kit";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { flake-utils, dev-kit, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      {
        devShells.default = dev-kit.lib.mkShell {
          inherit system;
          preCommitHooks = {
            fmt.enable = false;  # FIXME: implement `fmt` make target
            lint.enable = false;  # FIXME: implmenet `lint` make target
          };
          shellHook = "make setup";
        };
      }
    );
}
