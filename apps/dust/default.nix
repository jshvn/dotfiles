# dust (du replacement): the formula, its config, and the aliases that only make sense with it.
{ config, lib, ... }:
{
  options.dotfiles.apps.dust.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.dust.enable {
    dotfiles.provided.formulae = [ "dust" ];
    dotfiles.shell.aliases.dust = "apps/dust/aliases.zsh";
    dotfiles.links.".config/dust/config.toml" = "apps/dust/config.toml";
  };
}
