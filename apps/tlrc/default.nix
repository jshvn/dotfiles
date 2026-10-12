# tlrc (tldr client): the formula, its config.toml, and the TLRC_CONFIG export without which
# tlrc reads ~/Library/Application Support/tlrc instead of the linked config.toml.
{ config, lib, ... }:
{
  options.dotfiles.apps.tlrc.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.tlrc.enable {
    dotfiles.provided.formulae = [ "tlrc" ];
    dotfiles.shell.env.tlrc = "apps/tlrc/env.zsh";
    dotfiles.links.".config/tlrc/config.toml" = "apps/tlrc/config.toml";
  };
}
