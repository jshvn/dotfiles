# Homebrew installs everything, rolling, against the existing /opt/homebrew (bootstrap.zsh's
# consent-gated installer stays the one curl-to-shell). A switch is an update, as `task install`
# is today; cleanup uninstalls whatever is no longer declared.
{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
  };
}
