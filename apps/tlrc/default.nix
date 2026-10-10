# tlrc (tldr client): a base app, always on; shell/.zshrc exports TLRC_CONFIG for it.
{ ... }:
{
  dotfiles.provided.formulae = [ "tlrc" ];
  dotfiles.links.".config/tlrc/config.toml" = "apps/tlrc/config.toml";
}
