# Identity selection (was machine.identity plus the `# capability:` sentinels): which git and
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
  };
}
