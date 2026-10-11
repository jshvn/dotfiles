# Firefox: the cask, and the BROWSER export that tools opening a browser from the shell read.
{ config, lib, ... }:
{
  options.dotfiles.apps.firefox.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.firefox.enable {
    dotfiles.provided.casks = [ "firefox" ];
    dotfiles.shell.env.firefox = "apps/firefox/env.zsh";
  };
}
