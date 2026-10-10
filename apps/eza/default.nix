# eza (ls replacement): a base app, always on, because shell/aliases/general.zsh depends on it.
{ ... }:
{
  dotfiles.provided.formulae = [ "eza" ];
  dotfiles.links.".config/eza/theme.yaml" = "apps/eza/theme.yaml";
}
