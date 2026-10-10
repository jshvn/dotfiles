# tasks

What `Taskfile.yml` runs. The Taskfile holds one evaluation of the selected machine (`SHAPE`:
the `dotfiles` namespace, every defaults group, the ByHost keys, the generated Brewfile, taps,
casks, hostname) and pipes it as JSON to the scripts here.

Naming: `<task>.zsh` is the body of `task <task>`; `<task>-<thing>.zsh` is a helper of that task,
so `ls` sorts each helper next to its owner; `messages.zsh` is the shared output library
(`bootstrap.zsh` and `apps/claude-code/` source it too). A test in `tests/` takes the name of
the script it tests.

| Script | Task | Does |
|--------|------|------|
| `audit.zsh` | `task audit [-- --strict]` | the other direction from validate: what is on the machine beyond the declaration (brew bundle cleanup dry run, taps and trust grants, orphan links into the checkout) and `brew vulns`. Findings warn; `--strict` exits 1. |
| `audit-brew-cleanup.zsh` | by audit | what `brew bundle cleanup` would uninstall, from its dry run |
| `audit-links.zsh` | by audit | the orphan-link detector |
| `audit-trust.zsh` | by audit | tap and trust-grant drift |
| `install.zsh` | `task install` | builds the selected machine; on a Mac's first switch clears the way (`install-clear-links.zsh`, then `/etc/zshenv` and `/etc/shells` aside); switches; then lets brew uninstall what is installed beyond the declaration only after asking (`-- --yes` answers yes) |
| `install-clear-links.zsh` | by install | removes the symlinks at the registered link paths and moves anything else there to `<path>.before-dotfiles` |
| `install-repo-sync.zsh` | by install | fast-forwards this checkout before the build, warn-only; the claude-code activation runs it on the jshvn/ai checkout too (`$REPO_SYNC`) |
| `lint.zsh` | `task lint` | every `.zsh` parses; every executable one sets `-euo pipefail`; every one carries the Purpose / Depends on / Side effects banner; no hardcoded Homebrew prefix outside a `# lint-allow: hardcoded-prefix` line. The Taskfile adds `nix fmt -- --ci` in the image; `task fmt` applies it. |
| `validate.zsh` | `task validate` | reads the whole declaration back from the live system: shell plumbing, hostname, every link, the profile's identity (stray files in `profiles/`, git email, agent socket, `ssh-add -L`), `brew bundle check` and every cask's app artifact, the jshvn/ai checkout, every defaults key, the display preset, the Spotlight hotkey, the application firewall. Exits 1 on any cross. |
| `messages.zsh` | sourced | info / success / warn / error / check / cross; the claude-code activation takes it by path (`$MESSAGES`) |
| `tests/` | `task test` | one per helper above (hermetic, run in CI too); `ai-checkout` (`apps/claude-code/checkout.zsh`); `shell-startup` (the live shell: Mac only); `negative.sh` (the declaration rules, broken on purpose, inside the image) |

Input contract: `validate.zsh` and `audit.zsh` read the evaluation on stdin and refuse empty
input. They run read-only; the one side effect is a temp file for the Brewfile.

The one-check rule: pipeline logic here gets a test under `tests/`; interactive functions and
aliases do not.
