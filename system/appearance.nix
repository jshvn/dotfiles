{ config, lib, ... }:
{
  options.dotfiles.system.appearance = lib.mkOption {
    type = lib.types.bool;
    description = "system Dark mode, icon and widget style";
  };

  config = lib.mkIf config.dotfiles.system.appearance {
    system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark";
    system.defaults.CustomUserPreferences.NSGlobalDomain.AppleIconAppearanceTheme = "RegularDark";
  };
}
