# ssh: a base app, always on. The shared config (every host through the 1Password agent), the
# cloudflared ProxyCommand wrapper, the profile's host blocks and public key, and GitHub's host keys.
{ config, lib, ... }:
let
  profile = "profiles/${config.dotfiles.profile}";
in
{
  dotfiles.provided.formulae = [ "openssh" ];
  dotfiles.links = {
    ".ssh/config" = "apps/ssh/config";
    ".ssh/cloudflared.zsh" = "apps/ssh/cloudflared.zsh";
    ".ssh/profile" = "${profile}/ssh";
    ".ssh/profile.pub" = "${profile}/key.pub";
  };

  # GitHub's published host keys in /etc/ssh/ssh_known_hosts, so ssh to github.com never stops
  # at an unknown host; the switch's clone of jshvn/ai (apps/claude-code) runs in BatchMode and
  # cannot answer that prompt. Homebrew's ssh, first on that step's PATH, reads this file only
  # because apps/ssh/config names it. Source and fingerprints:
  #   https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  #   https://api.github.com/meta (ssh_keys)
  programs.ssh.knownHosts =
    lib.mapAttrs
      (_: publicKey: {
        hostNames = [ "github.com" ];
        inherit publicKey;
      })
      {
        github-ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        github-ecdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
        github-rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
      };
}
