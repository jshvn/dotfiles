{ config, lib, ... }:
{
  options.dotfiles.system.animations = lib.mkOption {
    type = lib.types.bool;
    description = "short AppKit window and Quick Look animations";
  };

  config = lib.mkIf config.dotfiles.system.animations {
    # the Spaces slide and Mission Control have no key on macOS 27 (docs/DECISIONS.md)
    system.defaults.NSGlobalDomain = {
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowResizeTime = 0.001;
    };
    system.defaults.CustomUserPreferences.NSGlobalDomain.QLPanelAnimationDuration = 0.0;
  };
}
