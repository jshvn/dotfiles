# tlrc (tldr client): a base app, always on; env.zsh exports TLRC_CONFIG, without which tlrc
# reads ~/Library/Application Support/tlrc instead of the linked config.toml.
{ ... }:
{
  dotfiles.provided.formulae = [ "tlrc" ];
  dotfiles.shell.env.tlrc = "apps/tlrc/env.zsh";
  dotfiles.links.".config/tlrc/config.toml" = "apps/tlrc/config.toml";
}
