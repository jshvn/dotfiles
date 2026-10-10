# The unconditional tier: the bootstrap toolchain and what shell/
# breaks without. A base tool with a config file is an app directory instead (eza, tlrc).
{ ... }:
{
  dotfiles.provided.formulae = [
    "antidote"
    "cloudflared"
    "coreutils"
    "fastfetch"
    "git"
    "git-delta"
    "go-task"
    "grc"
    "grep"
    "highlight"
    "jq"
    "libpsl"
    "mas"
    "ncdu"
    "onefetch"
    "openssh"
    "rdap"
    "trippy"
    "whois"
    "yq"
    "zsh"
  ];
  homebrew.taps = [ "homebrew/brew-vulns" ]; # a bare tap: only the `brew vulns` command
}
