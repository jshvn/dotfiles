# herdr (terminal workspace manager for agents): the formula and its config.
{ config, lib, ... }:
{
  options.dotfiles.apps.herdr.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.herdr.enable {
    dotfiles.provided.formulae = [ "herdr" ];
    dotfiles.links.".config/herdr/config.toml" = "apps/herdr/config.toml";
  };
}
