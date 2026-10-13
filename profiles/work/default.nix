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
      updates = false;
      appearance = true;
      display = true;
      animations = true;
      dockApps = null;
    };
    apps = {
      raycast = {
        enable = true;
        freeCmdSpace = false;
      };
      ghostty.enable = true;
      terminal.enable = true;
      herdr.enable = false;
      vscode.enable = true;
      claude-code = {
        enable = true;
        profile = "work";
        ref = "main";
      };
      dust.enable = false;
      wget.enable = true;
      firefox.enable = true;
      terraform.enable = false;
      tlrc.enable = true;
    };
    shell.jgrid-net = false;
    shell.motd = false;
    repo.devToolchain = true;
    packages = {
      formulae = [
        "bat"
        "bottom"
        "duf"
        "fd"
        "gh"
        "git-crypt"
        "htop"
        "hugo"
        "uv"
      ];
      casks = [
        "1password-cli"
        "alcove"
        "appcleaner"
        "cardhop"
        "fantastical"
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
