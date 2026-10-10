# Homebrew installs everything, rolling, against the existing /opt/homebrew (bootstrap.zsh runs
# its consent-gated installer, one of the two curl-to-shells). A switch is an update, so
# `task install` upgrades. The switch never uninstalls: `task install` then lets brew list what is
# installed beyond the declaration and uninstall it only after asking (tasks/install.zsh), so a
# first switch and a rollback never remove anything.
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
    };
  };
}
