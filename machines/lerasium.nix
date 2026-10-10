# lerasium, the personal MacBook Pro: the personal profile plus the names this machine answers to
# (was the machine-local hostname state file).
{
  imports = [ ../profiles/personal.nix ];
  networking = {
    hostName = "lerasium";
    computerName = "lerasium";
    localHostName = "lerasium";
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
}
