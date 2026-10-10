# tasks

What `Taskfile.yml` runs. The Taskfile holds one evaluation of the selected machine (`SHAPE`:
the `dotfiles` namespace, every defaults group, the ByHost keys, the generated Brewfile, taps,
casks, hostname) and pipes it as JSON to the scripts here.

| Script | Task | Does |
|--------|------|------|
| `validate.zsh` | `task validate` | reads the whole declaration back from the live system: shell plumbing, hostname, every link, identity (keys, git email, agent socket, `ssh-add -L`), `brew bundle check` and every cask's app artifact, the jshvn/ai checkout, every defaults key, the display preset, the Spotlight hotkey, the application firewall. Exits 1 on any cross. |
| `audit.zsh` | `task audit [-- --strict]` | the other direction: what is on the machine beyond the declaration (brew bundle cleanup dry run, taps and trust grants, orphan links into the checkout) and `brew vulns`. Findings warn; `--strict` exits 1. |
| `lint.zsh` | `task lint` | every `.zsh` parses; every executable one sets `-euo pipefail`; every one carries the Purpose / Depends on / Side effects banner; no hardcoded Homebrew prefix outside a `# lint-allow: hardcoded-prefix` line. The Taskfile adds `nix fmt -- --ci` in the image; `task fmt` applies it. |
| `install.zsh` | `task install` | builds the selected machine; on a Mac's first switch clears the way (`clear-links.zsh`, then `/etc/zshenv` and `/etc/shells` aside); switches; then lets brew uninstall what is installed beyond the declaration only after asking (`-- --yes` answers yes) |
| `messages.zsh` | sourced | info / success / warn / error / check / cross |
| `clear-links.zsh` | by install | removes the symlinks at the registered link paths and moves anything else there to `<path>.before-dotfiles` |
| `brew-cleanup-scan.zsh` | by audit | what `brew bundle cleanup` would uninstall, from its dry run |
| `links-audit-scan.zsh` | by audit | the orphan-link detector |
| `packages-trust-scan.zsh` | by audit | tap and trust-grant drift |
| `tests/` | `task test` | `shell-startup` (the live shell: Mac only), `links-audit`, `packages-trust`, `install` (the cleanup scan and link clearing), `repo-sync`, `ai-checkout` (hermetic, run in CI too), `negative.sh` (the declaration rules, broken on purpose, inside the image) |

Input contract: `validate.zsh` and `audit.zsh` read the evaluation on stdin and refuse empty
input. They run read-only; the one side effect is a temp file for the Brewfile.

The one-check rule: pipeline logic here gets a test under `tests/`; interactive functions and
aliases do not.
