# harmonium, the second personal MacBook. Confirm `uname -m` before the first switch. flake.nix
# derives its network names from this file name.
{
  imports = [ ../profiles/personal ];
  nixpkgs.hostPlatform = "aarch64-darwin";
}
