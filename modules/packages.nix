# The package tiers (base, what an enabled app provides, a profile's free choices) and the
# redundancy rule: a profile may not list what base or an enabled app already provides.
# Everything is Homebrew, rolling. Taps are derived from tap-qualified names, never listed.
{ config, lib, ... }:
let
  cfg = config.dotfiles;
  names = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };
  shape = {
    formulae = names;
    casks = names;
  };
  overlap = b: lib.intersectLists cfg.packages.${b} cfg.provided.${b};
  formulae = lib.unique (cfg.provided.formulae ++ cfg.packages.formulae);
  tapOf = n: lib.concatStringsSep "/" (lib.take 2 (lib.splitString "/" n));
in
{
  options.dotfiles.packages = shape // {
    mas = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
    };
  };
  options.dotfiles.provided = shape; # what base.nix, apps/ and repo.nix contribute

  config = {
    assertions = map (b: {
      assertion = overlap b == [ ];
      message = "packages.${b} lists what base or an enabled app already provides: ${toString (overlap b)}";
    }) (builtins.attrNames shape);

    homebrew.brews = formulae;
    homebrew.casks = lib.unique (cfg.provided.casks ++ cfg.packages.casks);
    homebrew.masApps = cfg.packages.mas;
    homebrew.taps = lib.unique (map tapOf (builtins.filter (lib.hasInfix "/") formulae));
  };
}
