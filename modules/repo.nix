# The pipeline's own knob. The checkout is always fast-forwarded by `task install` before a
# switch; that is not a per-machine choice.
{ config, lib, ... }:
{
  options.dotfiles.repo.devToolchain = lib.mkOption {
    type = lib.types.bool;
    description = "linters, formatters, hyperfine and Apple's container runtime for working on this repo";
  };

  # container: the engine `task check`, `lint`, `fmt` and `test` run the nix image in.
  config.dotfiles.provided.formulae = lib.mkIf config.dotfiles.repo.devToolchain [
    "biome"
    "container"
    "hyperfine"
    "ruff"
    "shellcheck"
    "shfmt"
  ];
}
