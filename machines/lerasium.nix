# lerasium, the personal MacBook Pro: the personal profile plus the names this machine answers to.
{
  imports = [ ../profiles/personal.nix ];
  networking = {
    hostName = "lerasium";
    computerName = "lerasium";
    localHostName = "lerasium";
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
}
