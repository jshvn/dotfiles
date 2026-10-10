# The work MacBook; the identity is the files beside this one. No machine file imports it yet;
# the flake check evaluates it under a synthetic machine, so it cannot rot.
{ ... }:
{
  dotfiles = {
    profile = "work";
    system = {
      dock = true;
      finder = true;
      input = true;
      screenshots = true;
      security = true;
      appearance = true;
      display = true;
      animations = true;
    };
    apps = {
      raycast = {
        enable = true;
        freeCmdSpace = false;
      };
      ghostty.enable = true;
      herdr.enable = false;
      vscode.enable = true;
      claude-code = {
        enable = true;
        profile = "work";
        ref = "2026.09.23";
      };
      conda.enable = true;
      dust.enable = false;
      wget.enable = true;
    };
    shell.jgrid-net = false;
    repo.devToolchain = true;
    packages = {
      formulae = [
        "bat"
        "bottom"
        "container"
        "doggo"
        "duf"
        "fd"
        "gh"
        "git-crypt"
        "htop"
        "hugo"
        "poppler"
        "uv"
      ];
      casks = [
        "1password-cli"
        "alcove"
        "appcleaner"
        "cardhop"
        "fantastical"
        "firefox"
        "gitfox"
        "microsoft-excel"
        "microsoft-powerpoint"
        "microsoft-word"
        "slack"
        "spotify"
        "standard-notes"
        "zed"
        "zoom"
      ];
      mas.Things3 = 904280696;
    };
  };
}
