# Claude Code: the app, and the jshvn/ai checkout that configures it. An activation step,
# because that repo owns its own install: the checkout is put at the pinned ref, told its
# profile (that repo's `task setup`, which writes its own state file), then installed.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.claude-code;
  user = config.system.primaryUser;
  # activation runs as root with nix-darwin's PATH; the user steps need Homebrew's tools
  path = "${config.homebrew.prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  task = "${config.homebrew.prefix}/bin/task";
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
    # it at run time; messages.zsh comes in by path because it lives under tasks/. The chain warns
    # instead of aborting the switch (offline, an unknown ref, the ai repo's install failing);
    # task validate reads the checkout and the ai repo's state back.
    system.activationScripts.postActivation.text = lib.mkIf cfg.enable ''
      sudo -u ${user} -H env PATH=${path} AI_DIR=${cfg.dir} AI_REMOTE=git@github.com:jshvn/ai.git AI_REF=${cfg.ref} AI_SYNC=true \
        MESSAGES=${../../tasks/messages.zsh} zsh ${./.}/checkout.zsh \
        && sudo -u ${user} -H env PATH=${path} ${task} -d ${cfg.dir} setup -- ${cfg.profile} \
        && sudo -u ${user} -H env PATH=${path} ${task} -d ${cfg.dir} install \
        || echo "claude-code: the jshvn/ai checkout, setup or install failed (above); the switch continues" >&2
    '';
  };
}
