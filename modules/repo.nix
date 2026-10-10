# The pipeline's own knob. The checkout is always fast-forwarded by `task install` before a
# switch; that is not a per-machine choice.
{ config, lib, ... }:
{
  options.dotfiles.repo.devToolchain = lib.mkOption {
    type = lib.types.bool;
    description = "linters, formatters and hyperfine for working on this repo";
  };

  config.dotfiles.provided.formulae = lib.mkIf config.dotfiles.repo.devToolchain [
    "biome"
    "hyperfine"
    "ruff"
    "shellcheck"
    "shfmt"
    "taplo"
  ];
}
