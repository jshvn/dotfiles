# macOS settings by System Settings concern. Each file declares
# its own dotfiles.system.<concern> switch, with no default: a profile sets every one true or
# false, or evaluation fails naming the concern. A typed nix-darwin option where one exists;
# CustomUserPreferences for a plain key it lacks; an activation script only where `defaults
# write` is the wrong tool. A concern with shell integration is a directory (finder/).
{ lib, ... }:
{
  imports = [
    ./dock.nix
    ./finder
    ./input.nix
    ./appearance.nix
    ./screenshots.nix
    ./animations.nix
    ./security.nix
    ./display.nix
  ];
}
