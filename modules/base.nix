# The unconditional tier: the bootstrap toolchain and what shell/
# breaks without. A base tool with a config file is an app directory instead (eza, git, ssh).
{ ... }:
{
  dotfiles.provided.formulae = [
    "antidote"
    "cloudflared"
    "coreutils"
    "doggo"
    "fastfetch"
    "go-task"
    "grc"
    "grep"
    "highlight"
    "jq"
    "libpsl"
    "mas"
    "onefetch"
    "rdap"
    "taplo"
    "trippy"
    "whois"
    "yq"
    "zsh"
  ];
  homebrew.taps = [ "homebrew/brew-vulns" ]; # a bare tap: only the `brew vulns` command
}
