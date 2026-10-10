# Visual Studio Code: the cask (it provides the `code` CLI the extensions install through) and
# the extension set that travels with it. A profile adds its own extras; listing one of these
# again is an error. Settings live under ~/Library/Application Support/Code/User, not XDG, and
# are not managed yet.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.vscode;
  bundled = [
    "1password.op-vscode"
    "anthropic.claude-code"
    "biomejs.biome"
    "charliermarsh.ruff"
    "docker.docker"
    "eamodio.gitlens"
    "github.vscode-github-actions"
    "jnoortheen.nix-ide"
    "mathematic.vscode-pdf"
    "mechatroner.rainbow-csv"
    "ms-azuretools.vscode-containers"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.vscode-python-envs"
    "ms-toolsai.jupyter"
    "ms-toolsai.jupyter-keymap"
    "ms-toolsai.jupyter-renderers"
    "ms-toolsai.vscode-jupyter-cell-tags"
    "ms-toolsai.vscode-jupyter-slideshow"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "ms-vscode.makefile-tools"
    "ms-vscode.remote-explorer"
    "pkief.material-icon-theme"
    "redhat.vscode-yaml"
    "task.vscode-task"
  ];
  overlap = lib.intersectLists bundled cfg.extensions;
in
{
  options.dotfiles.apps.vscode = {
    enable = lib.mkOption { type = lib.types.bool; };
    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "this machine's extensions beyond the bundled set";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = overlap == [ ];
        message = "apps.vscode.extensions lists what the app already bundles: ${toString overlap}";
      }
    ];
    dotfiles.provided.casks = [ "visual-studio-code" ];
    homebrew.vscode = bundled ++ cfg.extensions;
  };
}
