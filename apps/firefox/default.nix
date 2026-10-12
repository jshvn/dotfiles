# Firefox: the cask, the BROWSER export that tools opening a browser from the shell read, and the
# settings Firefox Sync does not carry, as a policy Firefox reads from the org.mozilla.firefox
# defaults domain at every launch. Sync owns everything else. When Sync starts carrying a
# preference below, remove it here; `task validate` warns, from the installed Firefox's list.
#
# Status "user" makes each preference win at every launch: change it here, not in the browser.
# SearchEngines.Default applies only when its value changes; Sync has no engine for search engines.
# toolbar.json is browser.uiCustomization.state; its browser actions are Privacy Badger, uBlock
# Origin, 1Password and SingleFile. When the toolbar changes in Firefox (a customization, or a
# button a Firefox update or a new add-on adds), copy it back before restarting: the launch puts
# the declared layout back, and only a copy records the new currentVersion and seen list, without
# which Firefox adds those buttons again at every launch.
#   state=$(sed -n 's/^user_pref("browser.uiCustomization.state", \(.*\));$/\1/p' ~/Library/Application\ Support/Firefox/Profiles/*.default-release/prefs.js | jq -e fromjson) && print -r -- "$state" > apps/firefox/toolbar.json
{ config, lib, ... }:
{
  options.dotfiles.apps.firefox.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.firefox.enable {
    dotfiles.provided.casks = [ "firefox" ];
    dotfiles.shell.env.firefox = "apps/firefox/env.zsh";
    system.defaults.CustomUserPreferences."org.mozilla.firefox" = {
      EnterprisePoliciesEnabled = true;
      Preferences =
        lib.mapAttrs
          (_: Value: {
            inherit Value;
            Status = "user";
          })
          {
            "browser.uiCustomization.state" = builtins.toJSON (lib.importJSON ./toolbar.json);
            # without it Firefox puts sidebar-button in a new profile's nav-bar; the layout leaves it out
            "browser.toolbarbuttons.introduced.sidebar-button" = true;
            # without it Firefox puts an Import bookmarks button on a new profile's bookmarks bar
            "browser.bookmarks.addedImportButton" = true;
            "browser.toolbars.bookmarks.visibility" = "always";
            "extensions.unifiedExtensions.button.always_visible" = false;
            "sidebar.visibility" = "hide-launcher";
            "browser.warnOnQuitShortcut" = false;
            # DNS over HTTPS off: the AdGuard DNS configuration profile already does it, system-wide
            "network.trr.mode" = 5;
            # 1Password fills cards
            "extensions.formautofill.creditCards.enabled" = false;
            "browser.discovery.enabled" = false;
          };
      SearchEngines.Default = "Bing";
    };
  };
}
