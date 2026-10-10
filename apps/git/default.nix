# git: a base app, always on. The shared config and global ignore, and the profile's overlay (its
# email and signing key), which the config includes for every repository under ~/git/.
{ config, ... }:
{
  dotfiles.provided.formulae = [
    "git"
    "git-delta"
  ];
  dotfiles.links = {
    ".config/git/config" = "apps/git/config";
    ".config/git/ignore" = "apps/git/ignore";
    ".config/git/profile" = "profiles/${config.dotfiles.profile}/git";
  };
}
