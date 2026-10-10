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
      appearance = true;
      display = true;
      animations = true;
    };
    apps = {
      raycast = {
        enable = true;
        freeCmdSpace = true;
      };
      ghostty.enable = true;
      herdr.enable = true;
      vscode = {
        enable = true;
        extensions = [ "golang.go" ];
      };
      claude-code = {
        enable = true;
        profile = "personal";
        ref = "main";
      };
      conda.enable = true;
      dust.enable = true;
    };
    shell.jgrid-net = true;
    repo.devToolchain = true;
    packages = {
      # container: Apple's runtime. hashicorp/tap/terraform: BSL, from HashiCorp's own tap.
      formulae = [
        "bat"
        "bottom"
        "container"
        "doggo"
        "duf"
        "fd"
        "gh"
        "git-crypt"
        "go"
        "hashicorp/tap/terraform"
        "htop"
        "hugo"
        "node"
        "poppler"
        "uv"
        "wget"
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
        "firefox"
        "gitfox"
        "microsoft-excel"
        "microsoft-powerpoint"
        "microsoft-word"
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
