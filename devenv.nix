{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  # https://devenv.sh/packages/
  packages = [
    pkgs.gnumake
    pkgs.jq
    pkgs.yq-go
    pkgs.kind
    pkgs.kubectl
    pkgs.kubernetes-helm
    inputs.ocm.packages.${pkgs.stdenv.system}.ocm
  ];

  # See full reference at https://devenv.sh/reference/options/

  difftastic.enable = true;
  delta.enable = true;
}
