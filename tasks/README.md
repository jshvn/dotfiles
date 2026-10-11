# tasks

This directory contains the scripts that `Taskfile.yml` starts. The Taskfile evaluates the
selected machine one time. This evaluation is `SHAPE`. The Taskfile sends it as JSON to the
scripts here.

`SHAPE` contains:

- the `dotfiles` namespace
- each defaults group
- the ByHost keys
- the generated Brewfile
- the taps and the casks
- the hostname

File names:

- `<task>.zsh` is the body of `task <task>`.
- `<task>-<thing>.zsh` is a helper of that task. With this name, `ls` sorts each helper next
  to its task.
- `messages.zsh` is the shared output library. `bootstrap.zsh` and the activation steps of
  `apps/claude-code/` and `apps/vscode/` also use it.
- A test in `tests/` has the name of the script that it tests.

| Script | Task | Function |
|--------|------|----------|
| `audit.zsh` | `task audit [-- --strict]` | Does the opposite check of `validate.zsh`. Finds the state on the machine that is not in the configuration. Uses the three `audit-*` helpers. Also does `brew vulns`. Each finding is a warning. With `--strict`, exits with code 1 if there is a finding. |
| `audit-brew-cleanup.zsh` | Used by `audit.zsh` and `prune.zsh` | Finds the packages that `brew bundle cleanup` would remove. Uses its dry run. |
| `audit-links.zsh` | Used by `audit.zsh` | Finds orphan links into the checkout. |
| `audit-trust.zsh` | Used by `audit.zsh` | Finds changes in the taps and the trust grants. |
| `install.zsh` | `task install` | Builds the selected machine. On the first switch on a Mac, it does `install-clear-links.zsh`. Then it moves `/etc/zshenv` and `/etc/shells` to `*.before-nix-darwin`. Then it does the switch. Then it lists the packages that are not in the configuration, with `prune.zsh --list`. Then it does `install-pins.zsh`. |
| `install-pins.zsh` | Used by `install.zsh` | Finds each pinned version that the install does not update and that is out of date: the `flake.lock` inputs (only after 7 days), the NixOS release, the `nixos/nix` image, the GitHub Actions versions, macOS updates and a jshvn/ai tag. Shows a warning with the update procedure for each. If a lookup fails, it shows a warning and continues. |
| `install-clear-links.zsh` | Used by `install.zsh` | Removes the symlinks at the registered link paths. Moves each other file at these paths to `<path>.before-dotfiles`. |
| `install-repo-sync.zsh` | Used by `install.zsh` | Fast-forwards this checkout before the build. If it cannot, it shows a warning and continues. The claude-code activation also uses it on the jshvn/ai checkout, through `$REPO_SYNC`. |
| `lint.zsh` | `task lint` | Makes sure that each `.zsh` file parses. Makes sure that each executable file sets `-euo pipefail`. Makes sure that each file has the Purpose / Depends on / Side effects banner. Makes sure that no file has a hardcoded Homebrew prefix, except on a `# lint-allow: hardcoded-prefix` line. The Taskfile also does `nix fmt -- --ci` in the image. `task fmt` applies the format. |
| `prune.zsh` | `task prune` | Removes the packages that are not in the configuration, with `brew bundle cleanup`. Brew shows the list and asks first. Without a terminal, it only shows the list. |
| `validate.zsh` | `task validate` | Reads the full configuration back from the live system. Exits with code 1 if a check fails. The list below shows the checks. |
| `messages.zsh` | Sourced | Supplies the functions info, success, warn, error, check and cross. The claude-code and vscode activations get it by its path, through `$MESSAGES`. |
| `tests/` | `task test` | Contains the tests. The list below shows them. |

`validate.zsh` checks these items:

- the shell plumbing. This includes the Nix in the default profile, which must be `nix.package`.
- the hostname
- each link
- the identity of the profile. This includes stray files in `profiles/`, the git email, the
  agent socket and `ssh-add -L`.
- `brew bundle check` and the app of each cask
- the jshvn/ai checkout
- each defaults key
- the display preset
- the symbolic hotkeys (Spotlight, input source, Finder search)
- the application firewall

`tests/` contains these tests:

- One test for each helper above. These tests are hermetic. CI also does them.
- `ai-checkout.zsh` tests `apps/claude-code/checkout.zsh`.
- `vscode-vsix.zsh` tests `apps/vscode/vsix.zsh`.
- `shell-startup.zsh` tests the live shell. It operates only on a Mac.
- `negative.sh` breaks the configuration rules on purpose. It operates in the image.

`validate.zsh` and `audit.zsh` read the evaluation on stdin. They refuse an empty input. They
do not change the system. Their only side effect is a temporary file for the Brewfile.

Pipeline logic in this directory must have a test in `tests/`. Interactive functions and
aliases do not get tests.
