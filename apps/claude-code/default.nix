# Claude Code: the app, and the jshvn/ai checkout that configures it (was the ai flag, [ai]
# profile / ref, taskfiles/ai.yml and install/ai-checkout.zsh). An activation step, because that
# repo owns its own install.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.claude-code;
in
{
  options.dotfiles.apps.claude-code = {
    enable = lib.mkOption { type = lib.types.bool; };
    profile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    ref = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "a branch (tracked and fast-forwarded) or a tag / commit (checked out detached)";
    };
    dir = lib.mkOption {
      type = lib.types.str;
      default = "/Users/josh/Git/personal/ai";
      description = "where the jshvn/ai checkout lives";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.enable == (cfg.profile != null && cfg.ref != null);
        message = "apps.claude-code: enable, profile and ref travel together";
      }
    ];
    dotfiles.provided.casks = lib.mkIf cfg.enable [ "claude-code" ];
    # ${./.} copies this whole directory into the store, so checkout.zsh finds repo-sync.zsh beside
    # it at run time; messages.zsh comes in by path because it lives under tasks/
    system.activationScripts.postActivation.text = lib.mkIf cfg.enable ''
      sudo -u josh env AI_DIR=${cfg.dir} AI_REMOTE=git@github.com:jshvn/ai.git AI_REF=${cfg.ref} AI_SYNC=true \
        MESSAGES=${../../tasks/messages.zsh} zsh ${./.}/checkout.zsh
      sudo -u josh env AI_PROFILE=${cfg.profile} ${config.homebrew.prefix}/bin/task -d ${cfg.dir} install
    '';
  };
}
