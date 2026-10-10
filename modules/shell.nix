# The shell is Homebrew zsh with the repo's own startup files, theme, functions and aliases, so
# nothing visible changes. nix-darwin's zsh and bash wiring stays off (Apple's /etc/zshrc,
# /etc/zprofile and /etc/bashrc untouched); the one system file declared is the ZDOTDIR line.
#
# Shell integration that belongs to an app or a System Settings concern lives beside it and is
# registered here: aliases.zsh files are linked into $XDG_STATE_HOME/dotfiles/aliases.d/ and
# login-env fragments into env.d/, only when their owner is on. The startup files read those two
# directories; whether a file is there is the gate.
{ config, lib, ... }:
let
  cfg = config.dotfiles;
  fragments = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "name -> path under the checkout";
  };
  into = dir: lib.mapAttrs' (n: p: lib.nameValuePair ".local/state/dotfiles/${dir}/${n}.zsh" p);
  startup = [
    ".zshenv"
    ".zprofile"
    ".zshrc"
    ".zlogin"
    ".zlogout"
  ];
in
{
  options.dotfiles.shell = {
    jgrid-net = lib.mkOption {
      type = lib.types.bool;
      description = "the jgrid.net fleet aliases";
    };
    aliases = fragments; # sourced by .zshrc, interactive shells
    env = fragments; # sourced by .zprofile, login shells
  };

  config = {
    dotfiles.shell.aliases = {
      general = "shell/aliases/general.zsh";
      dotfiles = "shell/aliases/dotfiles.zsh";
      hardware = "shell/aliases/hardware.zsh";
      networking = "shell/aliases/networking.zsh";
    }
    // lib.optionalAttrs cfg.shell.jgrid-net { jgrid = "shell/aliases/jgrid.zsh"; };

    dotfiles.links =
      lib.listToAttrs (map (n: lib.nameValuePair ".config/zsh/${n}" "shell/${n}") startup)
      // into "aliases.d" cfg.shell.aliases
      // into "env.d" cfg.shell.env;

    programs.zsh.enable = false;
    programs.bash.enable = false;
    environment.shells = [ "${config.homebrew.prefix}/bin/zsh" ]; # /etc/shells, so chsh accepts it
    environment.etc."zshenv".text = ''export ZDOTDIR="$HOME/.config/zsh"'';
  };
}
