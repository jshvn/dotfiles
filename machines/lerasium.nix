# lerasium, the personal MacBook Pro: the personal profile and its platform. flake.nix
# derives its network names from this file name.
{
  imports = [ ../profiles/personal ];
  nixpkgs.hostPlatform = "aarch64-darwin";
}
