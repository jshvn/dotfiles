{ config, lib, ... }:
{
  options.dotfiles.system.siri = lib.mkOption {
    type = lib.types.bool;
    description = "Siri off, no Siri menu bar icon";
  };

  config = lib.mkIf config.dotfiles.system.siri {
    # the Siri switch in Apple Intelligence & Siri; with Siri AI on, macOS 27 puts an "Ask Siri"
    # item at the top of every context menu
    system.defaults.CustomUserPreferences."com.apple.assistant.support"."Assistant Enabled" = false;
    system.defaults.CustomUserPreferences."com.apple.Siri".StatusMenuVisible = false;
  };
}
