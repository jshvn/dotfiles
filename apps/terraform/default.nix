# Terraform: the formula (BSL, from HashiCorp's own tap), and the CHECKPOINT_DISABLE export that
# turns off HashiCorp's version check, the only thing terraform writes to ~/.terraform.d unless
# logged in.
{ config, lib, ... }:
{
  options.dotfiles.apps.terraform.enable = lib.mkOption { type = lib.types.bool; };

  config = lib.mkIf config.dotfiles.apps.terraform.enable {
    dotfiles.provided.formulae = [ "hashicorp/tap/terraform" ];
    dotfiles.shell.env.terraform = "apps/terraform/env.zsh";
  };
}
