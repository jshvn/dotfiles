# Homebrew installs everything, rolling, against the existing /opt/homebrew (bootstrap.zsh runs
# its consent-gated installer, one of the two curl-to-shells). A switch is an update, so
# `task install` upgrades; cleanup uninstalls whatever is no longer declared, so what it would
# remove is read from `task audit` before it is turned on.
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # ponytail: "none" until the first switch on each laptop has had its audit read; then
      # "uninstall". A new machine's first switch sets this back to "none" locally (README).
      cleanup = "none";
    };
  };
}
