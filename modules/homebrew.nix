# Homebrew installs everything, rolling, against /opt/homebrew. The switch installs Homebrew
# itself when it is missing, with Homebrew's own installer, and Homebrew updates itself on every
# switch after that. A switch is an update, so `task install` upgrades. The switch never
# uninstalls: `task install` then lets brew list what is installed beyond the declaration and
# uninstall it only after asking (tasks/install.zsh), so a first switch and a rollback never
# remove anything.
{ config, lib, ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
    };
  };

  # nix-darwin aborts a switch when Homebrew is missing; the step below installs it instead
  system.checks.text = lib.mkBefore "INSTALLING_HOMEBREW=1";

  # Runs right before nix-darwin's brew bundle. The installer refuses root, so it runs as the
  # user and its own sudo calls reuse the password the switch just took. A failed install lets
  # the rest of the switch finish; nix-darwin's step then reports Homebrew missing.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    if [ ! -x ${config.homebrew.prefix}/bin/brew ]; then
      echo >&2 "installing Homebrew..."
      sudo -u ${config.system.primaryUser} -H env NONINTERACTIVE=1 PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
        echo >&2 "Homebrew install failed; task install tries again"
    fi
  '';
}
