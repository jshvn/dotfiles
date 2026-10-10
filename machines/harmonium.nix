# harmonium, the second personal MacBook. Confirm `uname -m` before the first switch.
{
  imports = [ ../profiles/personal.nix ];
  networking = {
    hostName = "harmonium";
    computerName = "harmonium";
    localHostName = "harmonium";
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
}
