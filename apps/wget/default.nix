# wget: the formula, its wgetrc (the HSTS cache under ~/.cache, not ~/.wget-hsts), and the
# WGETRC export that points wget at it: wget reads only ~/.wgetrc otherwise.
{ config, lib, ... }:
{
  options.dotfiles.apps.wget.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.wget.enable {
    dotfiles.provided.formulae = [ "wget" ];
    dotfiles.shell.env.wget = "apps/wget/env.zsh";
    dotfiles.links.".config/wget/wgetrc" = "apps/wget/wgetrc";
  };
}
