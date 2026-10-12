# Josh's personal MacBooks: every System Settings concern, every optional app, the shell and
# pipeline knobs, and the free package choices. The identity is the files beside this one. A
# machine file imports this directory and adds the names it answers to.
{ ... }:
{
  dotfiles = {
    profile = "personal";
    system = {
      dock = true;
      finder = true;
      input = true;
      screenshots = true;
      security = true;
      updates = true;
      appearance = true;
      display = true;
      animations = true;
      dockApps = [
        "/System/Applications/Apps.app"
        "/System/Applications/Maps.app"
        "/System/Applications/Photos.app"
        "/System/Applications/Messages.app"
        "/Applications/Discord.app"
        "/Applications/Proton Mail.app"
        "/Applications/Firefox.app"
        "/Applications/Fantastical.app"
        "/Applications/Things3.app"
        "/Applications/Standard Notes.app"
        "/Applications/Spotify.app"
        "/Applications/Gitfox.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/Ghostty.app"
        "/Applications/1Password.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/App Store.app"
        "/System/Applications/System Settings.app"
        "/System/Applications/iPhone Mirroring.app"
      ];
    };
    apps = {
      raycast = {
        enable = true;
        freeCmdSpace = true;
      };
      ghostty.enable = true;
      terminal.enable = true;
      herdr.enable = true;
      vscode = {
        enable = true;
        vsix."jshvn.title-buttons" = "git@github.com:jshvn/vscode-title-buttons.git";
      };
      claude-code = {
        enable = true;
        profile = "personal";
        ref = "main";
      };
      dust.enable = true;
      wget.enable = true;
      firefox.enable = true;
      terraform.enable = true;
      tlrc.enable = true;
    };
    shell.jgrid-net = true;
    repo.devToolchain = true;
    packages = {
      formulae = [
        "bat"
        "bottom"
        "duf"
        "fd"
        "gh"
        "git-crypt"
        "go"
        "htop"
        "hugo"
        "node"
        "uv"
      ];
      casks = [
        "1password-cli"
        "alcove"
        "appcleaner"
        "cardhop"
        "cloudflare-warp"
        "discord"
        "dropbox"
        "fantastical"
        "gitfox"
        "nvidia-geforce-now"
        "proton-drive"
        "proton-mail"
        "protonvpn"
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
