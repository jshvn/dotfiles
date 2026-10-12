# What every laptop shares: the one user, the checkout the live-edited files link from, the
# profile the machine imports, the link registry, Nix's own housekeeping, and the module tree. Nix
# installs nothing of its own; it evaluates the declaration and activates it. Homebrew installs
# everything.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles;
  user = "josh";
  home = "/Users/${user}";
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
      default = "${home}/Git/personal/dotfiles";
      description = "the checkout that shell/, profiles/, apps/ and system/ files are linked from, outside the store; machines/<name>.nix sets it when that laptop clones elsewhere, and task install refuses any other clone";
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
    system.primaryUser = user; # activation runs as root; user-scoped defaults apply to this user
    # ponytail: listing the login account in knownUsers is what lets nix-darwin own its shell,
    # though nix-darwin's option text says not to list the admin user. At the locked rev an
    # existing user only gets PrimaryGroupID and UserShell re-set and deletion is guarded;
    # isHidden is pinned in case a later rev starts syncing it. Recheck on every flake update.
    users.knownUsers = [ user ];
    users.users.${user} = {
      uid = 501;
      inherit home;
      shell = "${config.homebrew.prefix}/bin/zsh"; # Homebrew's zsh
      isHidden = false;
    };

    # One Nix on the Mac: the daemon, the GC job and darwin-rebuild run this package, and the
    # switch points the default profile (the interactive shell's nix and the Taskfile's NIX) at
    # it too. `latest` follows each upstream release on the nixpkgs release branch; `stable`
    # stays on one minor line for the branch's life.
    nix.package = pkgs.nixVersions.latest;
    system.activationScripts.postActivation.text = ''
      ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/default --set ${config.nix.package}
    '';
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Profile and defexpr under $XDG_STATE_HOME/nix: home-manager runs nix-env on every switch,
    # and nix-env otherwise makes ~/.nix-profile and ~/.nix-defexpr
    nix.settings.use-xdg-base-directories = true;
    nix.gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${user} =
        { config, ... }:
        {
          home.stateVersion = "26.05";
          # Homebrew installs every app; without this home-manager makes an empty
          # ~/Applications/Home Manager Apps on every switch
          targets.darwin.copyApps.enable = false;
          home.file = lib.mapAttrs (target: source: {
            source = config.lib.file.mkOutOfStoreSymlink "${cfg.checkout}/${source}";
          }) cfg.links;
        };
    };
    system.stateVersion = 7;
  };
}
