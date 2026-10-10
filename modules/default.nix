# What every laptop shares: the one user, the checkout the live-edited files link from, the
# profile the machine imports, the link registry, Nix's own housekeeping, and the module tree. Nix
# installs nothing of its own; it evaluates the declaration and activates it. Homebrew installs
# everything.
{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  imports = [
    ./packages.nix
    ./base.nix
    ./homebrew.nix
    ./shell.nix
    ./repo.nix
    ../system
    ../apps
  ];

  options.dotfiles = {
    checkout = lib.mkOption {
      type = lib.types.str;
      default = "/Users/josh/Git/personal/dotfiles";
      description = "the checkout that shell/, profiles/, apps/ and system/ files are linked from, outside the store";
    };
    profile = lib.mkOption {
      type = lib.types.enum (
        builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../profiles))
      );
      description = "the profiles/<name>/ directory the machine imports, named by the profile itself; the git, ssh and 1password apps link its git, ssh, key.pub and agent.toml";
    };
    links = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "home-relative link -> path under the checkout; home-manager installs each as an out-of-store symlink and task validate reads each back";
    };
  };

  config = {
    system.primaryUser = "josh"; # activation runs as root; user-scoped defaults apply to this user
    # ponytail: listing the login account in knownUsers is what lets nix-darwin own its shell,
    # though nix-darwin's option text says not to list the admin user. At the locked rev an
    # existing user only gets PrimaryGroupID and UserShell re-set and deletion is guarded;
    # isHidden is pinned in case a later rev starts syncing it. Recheck on every flake update.
    users.knownUsers = [ "josh" ];
    users.users.josh = {
      uid = 501;
      home = "/Users/josh";
      shell = "${config.homebrew.prefix}/bin/zsh"; # Homebrew's zsh
      isHidden = false;
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.josh =
        { config, ... }:
        {
          home.stateVersion = "26.05";
          home.file = lib.mapAttrs (target: source: {
            source = config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/${source}";
          }) cfg.links;
        };
    };
    system.stateVersion = 7;
  };
}
