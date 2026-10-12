{ config, lib, ... }:
let
  user = config.system.primaryUser;
  # an XML plist, as in apps/raycast/: old-style text stores strings, which macOS does not honor
  off =
    modifiers:
    lib.escapeShellArg (
      lib.generators.toPlist { escape = true; } {
        enabled = false;
        value = {
          parameters = [
            32
            49
            modifiers
          ];
          type = "standard";
        };
      }
    );
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
        60 ${off 262144} \
        61 ${off 786432} \
        65 ${off 1572864}
      sudo -u ${user} -H /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
    '';
  };
}
