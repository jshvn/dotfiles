# 1Password: the app (its bundle carries the SSH agent and op-ssh-sign), the agent config, and the
# login-shell socket export. Turned on by a real identity (modules/identity.nix), never by a profile.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps."1password";
in
{
  options.dotfiles.apps."1password".enable = lib.mkOption {
    type = lib.types.bool;
    description = "set by the identity (on for personal and work, off for none); a profile never sets it";
    readOnly = true;
  };

  config = lib.mkIf cfg.enable {
    dotfiles.provided.casks = [ "1password" ];
    dotfiles.shell.env."1password" = "apps/1password/env.zsh";
    dotfiles.links.".config/1Password/ssh/agent.toml" = "apps/1password/agent.toml";
  };
}
