# Visual Studio Code: the cask (it provides the `code` CLI the extensions install through) and
# the extension set that travels with it. A profile adds its own extras; listing one of these
# again is an error. An extension that is not on the Marketplace comes from a VSIX committed to
# its own repo (`vsix`), installed by an activation step. env.zsh exports COPILOT_HOME. Settings
# live under ~/Library/Application Support/Code/User, not XDG, and are not managed yet.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.vscode;
  user = config.system.primaryUser;
  # activation runs as root with nix-darwin's PATH; the user step needs Homebrew's code and jq
  path = "${config.homebrew.prefix}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  # the "<id> <remote>" pairs vsix.zsh takes
  vsixArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (id: remote: "${lib.escapeShellArg id} ${lib.escapeShellArg remote}") cfg.vsix
  );
  bundled = [
    "anthropic.claude-code"
    "biomejs.biome"
    "charliermarsh.ruff"
    "eamodio.gitlens"
    "github.vscode-github-actions"
    "github.vscode-pull-request-github"
    "golang.go"
    "jnoortheen.nix-ide"
    "mathematic.vscode-pdf"
    "mechatroner.rainbow-csv"
    "ms-azuretools.vscode-containers"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.vscode-python-envs"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
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
    vsix = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "extension id to the SSH remote of a repo that commits <name>.vsix at its root";
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
    dotfiles.shell.env.vscode = "apps/vscode/env.zsh";
    homebrew.vscode = bundled ++ cfg.extensions;
    # after brew bundle, which installs the cask and so `code`. Warns instead of aborting the
    # switch (offline, no SSH agent yet); Taskfile's SHAPE adds these ids to the Brewfile it hands
    # validate, audit and the cleanup, so they read back as declared and are never uninstalled.
    system.activationScripts.postActivation.text = lib.mkIf (cfg.vsix != { }) ''
      sudo -u ${user} -H env PATH=${path} MESSAGES=${../../tasks/messages.zsh} zsh ${./vsix.zsh} \
        ${vsixArgs} \
        || echo "vscode: installing an extension from its VSIX failed (above); the switch continues" >&2
    '';
  };
}
