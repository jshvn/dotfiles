{ config, lib, ... }:
let
  user = config.system.primaryUser;
in
{
  options.dotfiles.system.input = lib.mkOption {
    type = lib.types.bool;
    description = "keyboard and trackpad defaults, input-source and Finder-search shortcuts off";
  };

  config = lib.mkIf config.dotfiles.system.input {
    system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
    # Genmoji suggestions while typing
    system.defaults.CustomUserPreferences."com.apple.keyboard.preferences".IsMixmojiSuggestionsEnabled =
      false;
    # symbolic hotkeys 60 and 61 (^Space, ^⌥Space: switch input source, one layout here) and 65
    # (⌘⌥Space: Finder search window). -dict-add, as in apps/raycast/, keeps the rest of the table;
    # one -dict-add takes every pair (a second -dict-add is a defaults error)
    system.activationScripts.postActivation.text = ''
      sudo -u ${user} -H defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add \
        60 '{enabled = 0; value = { parameters = (32, 49, 262144); type = standard; }; }' \
        61 '{enabled = 0; value = { parameters = (32, 49, 786432); type = standard; }; }' \
        65 '{enabled = 0; value = { parameters = (32, 49, 1572864); type = standard; }; }'
      sudo -u ${user} -H /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
    '';
  };
}
