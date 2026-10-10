# Miniconda and its condarc. The lazy `conda` hook in shell/.zshrc guards on the binary.
{ config, lib, ... }:
{
  options.dotfiles.apps.conda.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.conda.enable {
    dotfiles.provided.casks = [ "miniconda" ];
    dotfiles.links.".config/conda/condarc" = "apps/conda/condarc";
  };
}
