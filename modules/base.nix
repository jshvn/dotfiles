# The unconditional tier: the bootstrap toolchain and what shell/
# breaks without. A base tool with a config file is an app directory instead (eza, git, ssh, tlrc).
{ ... }:
{
  dotfiles.provided.formulae = [
    "antidote"
    "cloudflared"
    "coreutils"
    "fastfetch"
    "go-task"
    "grc"
    "grep"
    "highlight"
    "jq"
    "libpsl"
    "mas"
    "ncdu"
    "onefetch"
    "rdap"
    "trippy"
    "whois"
    "yq"
    "zsh"
  ];
  homebrew.taps = [ "homebrew/brew-vulns" ]; # a bare tap: only the `brew vulns` command
}
