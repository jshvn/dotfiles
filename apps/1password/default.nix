# 1Password: a base app, always on, because every profile's ssh and git signing go through its
# agent. The app (its bundle carries the SSH agent and op-ssh-sign), the profile's agent config
# (which keys the agent offers, in order), and the login-shell socket export.
{ config, ... }:
{
  dotfiles.provided.casks = [ "1password" ];
  dotfiles.shell.env."1password" = "apps/1password/env.zsh";
  dotfiles.links.".config/1Password/ssh/agent.toml" =
    "profiles/${config.dotfiles.profile}/agent.toml";
}
