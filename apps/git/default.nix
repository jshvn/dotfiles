# git: a base app, always on. The shared config and global ignore, the functions directory the
# config's multi-line aliases run, the profile's overlay (its email, and signing on), which the
# config includes for every repository under ~/git/, and the allowed_signers file local
# signature verification reads, written from the profile's key.pub.
{ config, lib, ... }:
let
  key = ../../profiles + "/${config.dotfiles.profile}/key.pub";
  # "<type> <key> <comment>"; the comment is the profile's email, the principal git verifies
  fields = lib.splitString " " (lib.trim (builtins.readFile key));
in
{
  dotfiles.provided.formulae = [
    "git"
    "git-delta"
  ];
  dotfiles.links = {
    ".config/git/config" = "apps/git/config";
    ".config/git/ignore" = "apps/git/ignore";
    ".config/git/functions" = "apps/git/functions";
    ".config/git/profile" = "profiles/${config.dotfiles.profile}/git";
  };

  # a profile without a key yet (work) gets no file; verification then fails as it does unset
  assertions = lib.optional (builtins.pathExists key) {
    assertion = builtins.length fields == 3;
    message = "profiles/${config.dotfiles.profile}/key.pub: expected \"<type> <key> <email>\", the email being the allowed_signers principal";
  };
  home-manager.users.${config.system.primaryUser}.home.file.".config/git/allowed_signers" =
    lib.mkIf (builtins.pathExists key)
      {
        text = "${lib.elemAt fields 2} namespaces=\"git\" ${lib.elemAt fields 0} ${lib.elemAt fields 1}\n";
      };
}
