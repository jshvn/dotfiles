# Identity selection: which git and
# ssh overlay the machine links. Both real overlays route through the 1Password agent and sign
# with op-ssh-sign, so a real identity turns the 1Password app on; "none" turns it off.
{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  options.dotfiles.identity = lib.mkOption {
    type = lib.types.enum [
      "personal"
      "work"
      "none"
    ];
  };

  config = {
    dotfiles.apps."1password".enable = cfg.identity != "none";

    dotfiles.links = {
      ".config/git/config" = "identity/git/config";
      ".config/git/ignore" = "identity/git/ignore";
      ".config/git/identities" = "identity/git/identities";
      ".ssh/config" = "identity/ssh/config";
      ".ssh/identities/cloudflared.zsh" = "identity/ssh/cloudflared.zsh";
      ".ssh/identities/keys" = "identity/ssh/keys";
    }
    // lib.optionalAttrs (cfg.identity != "none") {
      ".ssh/identities/active" = "identity/ssh/identities/${cfg.identity}";
    };

    # GitHub's published host keys in /etc/ssh/ssh_known_hosts, so ssh to github.com never stops
    # at an unknown host; the switch's clone of jshvn/ai (apps/claude-code) runs in BatchMode and
    # cannot answer that prompt. Source and fingerprints:
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
  };
}
