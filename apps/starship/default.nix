# starship (the prompt): a base app, always on, because shell/theme.zsh draws the prompt with it.
{ ... }:
{
  dotfiles.provided.formulae = [ "starship" ];
  dotfiles.links.".config/starship.toml" = "apps/starship/starship.toml";
}
