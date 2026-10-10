# Raycast: the cask, the script-command directory beside this file (registered in Raycast by
# hand), and the one macOS setting that exists only for it: Spotlight's Cmd+Space, symbolic
# hotkey 64. Raycast's own hotkey is not declarable anywhere; Raycast cloud sync carries it.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.raycast;
  user = config.system.primaryUser;
in
{
  options.dotfiles.apps.raycast = {
    enable = lib.mkOption { type = lib.types.bool; };
    freeCmdSpace = lib.mkOption {
      type = lib.types.bool;
      description = "disable Spotlight's Cmd+Space so Raycast can claim it";
    };
  };

  config = lib.mkIf cfg.enable {
    dotfiles.provided.casks = [ "raycast" ];
    # ponytail: -dict-add rather than CustomUserPreferences, which would replace the whole
    # 22-entry hotkey table with this one entry. activateSettings reloads it without a logout.
    system.activationScripts.postActivation.text = lib.mkIf cfg.freeCmdSpace ''
      sudo -u ${user} -H defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
        '{enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'
      sudo -u ${user} -H /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
    '';
  };
}
