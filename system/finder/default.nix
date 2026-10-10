{ config, lib, ... }:
{
  options.dotfiles.system.finder = lib.mkOption {
    type = lib.types.bool;
    description = "Finder defaults and the Finder aliases";
  };

  config = lib.mkIf config.dotfiles.system.finder {
    system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
    system.defaults.finder = {
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "clmv";
    };
    system.defaults.CustomUserPreferences."com.apple.finder".DisableAllAnimations = true;
    dotfiles.shell.aliases.finder = "system/finder/aliases.zsh";
  };
}
