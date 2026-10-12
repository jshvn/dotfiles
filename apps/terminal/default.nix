# Terminal.app: the Clear Dark profile, in JetBrainsMono Nerd Font Mono 12 (the face Ghostty draws
# built in and VS Code is set to), as the default and startup profile, and the cask for the font.
# Terminal keeps every profile under one nested "Window Settings" key, with the font as archived
# NSFont data, and nix-darwin writes a nested value whole; -dict-add, as in system/input.nix,
# replaces Clear Dark and keeps the rest. Terminal reads its profiles at launch, so quit and reopen
# it after a switch that changes clear-dark.terminal. After changing the profile in Terminal, copy
# it back:
#   defaults export com.apple.Terminal - | plutil -extract 'Window Settings.Clear Dark' xml1 -o apps/terminal/clear-dark.terminal -
{ config, lib, ... }:
let
  user = config.system.primaryUser;
in
{
  options.dotfiles.apps.terminal.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.terminal.enable {
    dotfiles.provided.casks = [ "font-jetbrains-mono-nerd-font" ];
    system.defaults.CustomUserPreferences."com.apple.Terminal" = {
      "Default Window Settings" = "Clear Dark";
      "Startup Window Settings" = "Clear Dark";
    };
    system.activationScripts.postActivation.text = ''
      sudo -u ${user} -H defaults write com.apple.Terminal "Window Settings" -dict-add "Clear Dark" "$(<${./clear-dark.terminal})"
    '';
  };
}
