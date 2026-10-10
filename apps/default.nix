# Applications: one directory each, owning the install, the config files, the shell integration
# and any system setting that exists only for that app. An optional app declares
# dotfiles.apps.<name>.enable with no default, so a profile must say yes or no. A base app
# (1password, eza, git, ssh, tlrc: shell/ or every profile's identity breaks without it) declares
# nothing and is always on. Anything merely installed, with no config attached, is a package in
# the profile, not an app.
{ ... }:
{
  imports = [
    ./1password
    ./claude-code
    ./conda
    ./dust
    ./eza
    ./ghostty
    ./git
    ./herdr
    ./raycast
    ./ssh
    ./tlrc
    ./vscode
  ];
}
