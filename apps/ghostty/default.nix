# Ghostty: the cask, its config, and the `g` launcher alias.
{ config, lib, ... }:
{
  options.dotfiles.apps.ghostty.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.ghostty.enable {
    dotfiles.provided.casks = [ "ghostty" ];
    dotfiles.shell.aliases.ghostty = "apps/ghostty/aliases.zsh";
    dotfiles.links.".config/ghostty/config" = "apps/ghostty/config";
  };
}
