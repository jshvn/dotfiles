# Decisions, Scope, and Constraints

Locked decisions with rationale. The point is to prevent re-litigation; revisit only with
new evidence. Referenced from CLAUDE.md.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| nix-darwin evaluates and activates; Homebrew installs (v3, 2026-10-10) | The two earlier objections did not survive: go-task coexists with Nix (jgrid.net runs its fleet behind a go-task wrapper, and this repo keeps one), and the macOS 27 blocker (nix-darwin issue 1866) was a mac-app-util bug, not a nix-darwin one. What it buys: a small declaration (Nix modules plus a handful of scripts); the three declaration rules are module-system errors; non-defaults state (login shell, `/etc` files, launchd jobs) is native; generations give rollback; CI is a two-minute Linux evaluation; one mental model with jgrid.net. What it costs: sudo on every switch, a switch that takes 30 s to 2 min, and `/nix` on disk holding nix-darwin, home-manager, the Nix daemon nix-darwin runs and its CA bundle. |
| No nixpkgs packages, no nix-homebrew, no `environment.systemPackages`; the switch installs Homebrew | Every formula, cask, Mac App Store app and VS Code extension stays on Homebrew, rolling. When Homebrew is missing, the switch runs Homebrew's own installer just before `brew bundle` (`modules/homebrew.nix`), so the declaration, not bootstrap, owns getting Homebrew onto a Mac; Homebrew then updates itself on every switch, the day a release ships. nix-homebrew is out: it holds Homebrew at a version its maintainer bumps by hand, weeks behind, and switches self-update off, and the pinning and rollback it buys are worth nothing on machines that never roll back. The lock file pins only nix-darwin's own inputs; bootstrap runs go-task once from the locked nixpkgs to reach the first switch and installs nothing from it. |
| The terminal is the repo's own zsh | Homebrew zsh is the login shell; the repo's startup files, theme, MOTD, functions and aliases run. `programs.zsh` and `programs.bash` are off, so nix-darwin leaves Apple's `/etc/zshrc`, `/etc/zprofile` and `/etc/bashrc` alone; the Nix installer's block at the top of `/etc/zshrc` and `/etc/bashrc` is the one startup change. This repo declares two `/etc` files: `/etc/zshenv` (the ZDOTDIR line) and `/etc/shells` (Homebrew zsh, through `environment.shells`); nix-darwin also writes `/etc/nix/nix.conf` and others of its own. |
| Five option namespaces, no concept called "features" | `dotfiles.system.<concern>`, `apps.<name>`, `identity`, the `shell` and `repo` knobs, `packages`. Every optional switch has no default: a profile sets each one true or false or evaluation fails naming it. That is the every-flag-accounted rule, enforced by the module system. |
| One directory per application, owning everything about it | Install, config files, shell integration and any system setting that exists only for that app. Anything with configuration attached to its install is an app; anything merely installed is a package name in the profile. |
| The redundancy rule and derived taps | A profile may not list a formula or cask base or an enabled app provides, nor an extension VS Code bundles: an assertion fails. A tap-qualified formula implies its tap; `homebrew/brew-vulns` is the one bare tap, in `modules/base.nix`. |
| A real identity turns 1Password on, nothing else does | `dotfiles.identity` sets `apps."1password".enable` (readOnly); the identity is the only input. |
| Every link goes through `dotfiles.links`; shell gates are links | home-manager installs each entry as an out-of-store symlink, so an edit is live without a switch and `task validate` reads each back. An enabled app's or concern's `aliases.zsh` is linked into `$XDG_STATE_HOME/dotfiles/aliases.d/`, login-env fragments into `env.d/`; the startup files source those directories, and a file's presence is the gate. |
| Explicit machine selection at setup | `task setup -- <name>` (which `./bootstrap.zsh <name>` runs on a new Mac) writes the state file the Taskfile reads; the hostname lives in `machines/<name>.nix`. Nothing infers the machine from the live hostname; that has bitten us before. |
| One machine file per physical laptop, named after it | `lerasium` and `harmonium` import `profiles/personal.nix`. The work laptop is out of scope until it has a machine file; `profiles/work.nix` stays and the flake check evaluates it under a synthetic machine so it cannot rot. |
| `task install` always fast-forwards, then switches | No per-machine auto-update knob. The pull is warn-only: offline, a dirty tree or a diverged branch never block the switch. |
| Read-back validation stays | Nix activates state but never reads it back. One evaluation of the declaration feeds `show`, `diff`, `validate` and `audit`; `tasks/validate.zsh` reads each declared thing back from the live system: shell plumbing, hostname, links, identity, packages, the jshvn/ai checkout and every macOS default. |
| CI is the container | `nix flake check`, `nix fmt -- --ci` and the negative suite run in the pinned `nixos/nix` image on an ubuntu runner, with lint and the hermetic smoke tests beside them. A macOS runner, in parallel, installs Nix and builds lerasium's closure without switching. The switch, brew bundle, the live shell and the read-back tiers run only on a Mac. |
| `task install` uninstalls what is no longer declared, after asking | The switch never uninstalls (`cleanup = "none"`), so a first switch and a rollback never remove anything. `task install` then lets brew list what is installed beyond the declaration and uninstall it only on an explicit yes (or `-- --yes`). |
| Keep alanpeabody-based prompt; reject Starship | The existing `theme.zsh` is small, fast, and not on life support; Starship would be a behavior change with no problem to solve. |
| One command per Mac; no curl-to-shell except Homebrew's and Nix's own installers | `./bootstrap.zsh <machine>` installs Nix, selects the machine and runs the first `task install`, which clears the way for nix-darwin and home-manager itself and installs Homebrew, so no one-time procedure needs remembering. Both installers are HTTPS-only. The Nix installer is consent-gated and downloaded to a file first so it can be read before it runs; Homebrew's runs inside the switch, as the user, with no prompt of its own: the password the switch asks for is the consent (`docs/SECURITY.md`). |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself. |
| atium moved to `jshvn/jgrid.net` on 2026-09-23 | Its runtime needs (tunnel pair, secrets, nightly switch, healthcheck) were the NixOS common layer's; nix-darwin gave them a launchd backend. This repo is laptops-only. |
| No Spaces / Mission Control speed tweak; `system.animations` covers AppKit only | Measured on macOS 27.0 (2026-09-22): the Dock renders the ~1.2 s desktop slide itself and exposes no duration key. The legacy Dock keys (`expose-animation-duration`, `springboard-*-duration`, `workspaces-swoosh-animation-off`) exist in no macOS 27 binary, and `com.apple.WindowManager AnimationSpeed`, `ExposeSpringResponse`, `ExposeSpringDampingRatio` and `com.apple.dock mission-control-transition` all time identical to stock. Do not re-add them; revisit only if a later 27.x adds a key. |
| AI tooling config lives in `jshvn/ai`, not here | Claude Code is one tool among several. The seam is `apps.claude-code.{profile,ref,dir}` and that repo's documented contract: the switch clones it at the ref and runs its `task setup -- <profile>` and `task install` (passing `CLAUDE_CONFIG_DIR`, which activation's environment lacks); `task validate` runs its `task validate`. No environment variable carries the profile. Per-machine variation is a profile in that repo. |
| VS Code `settings.json` stays unmanaged | It lives under `~/Library/Application Support/Code/User`, not XDG; `apps/vscode/` is where it would go. |

## Out of Scope

Explicit boundaries with reasoning. The point is to prevent re-litigation; revisit only with
new evidence.

- **Linux / Windows / WSL** -- macOS-only is a deliberate simplification. All target machines
  are macOS laptops.
- **Servers** -- every server, Mac or not, is a jgrid.net fleet host.
- **nixpkgs packages, nix-homebrew, mac-app-util** -- Homebrew installs everything (above);
  mac-app-util was the source of nix-darwin issue 1866.
- **chezmoi / stow / yadm** -- a tool dependency that overlaps with what the switch does.
- **Starship prompt** -- the existing alanpeabody-based `theme.zsh` is small, fast, and not on
  life support.
- **fish / nu / bash** -- zsh is the chosen shell.
- **Replacing go-task** -- locked; it is the operator surface over darwin-rebuild and nix eval.
- **Hostname-based machine detection** -- burned us before. Explicit `task setup -- <machine>`
  only.
- **Inline profile branching in shared files** -- behavior varies only through the
  declaration: what a profile sets and the links the switch makes.
- **Auto-detection of identity / capabilities** -- the declaration is the source of truth.
- **The work laptop** -- until it has a machine file.
- **`sysadminctl -screenLock immediate`** -- wants the account password on a tty a switch does
  not have; a one-time manual step per machine.
- **Raycast's own hotkey** -- Raycast keeps it in its own database; only Raycast cloud sync
  carries it. The Spotlight half (symbolic hotkey 64) is declared.

## Performance and Security Constraints

- **Performance target** -- interactive shell cold start under 500 ms (the
  `task shell:startup-time` budget); a converged `task install` is one `darwin-rebuild
  switch` plus `brew update` and `brew bundle` (30 s to 2 min).
- **Security** -- no curl-to-shell except the Nix and Homebrew installers
  (`docs/SECURITY.md`); no secrets in the repo; public SSH keys only.
- **Idempotency** -- a converged `task install` changes nothing: `task diff` shows no closure
  change and `brew bundle check` is satisfied.

## Tooling Versions

| Tool | Pinned by | Reason |
|------|-----------|--------|
| nixpkgs, nix-darwin, home-manager (26.05 line) | `flake.lock` | the evaluator; `task check` and CI evaluate against the lock |
| Nix 2.35.2, the `nixos/nix` image by digest | `Taskfile.yml` | check, fmt, lint and the negative suite run the same image on a laptop and in CI |
| `go-task` >= 3.37 | Homebrew, `modules/base.nix`; bootstrap's first run, the locked nixpkgs | `for:` loops and the `OS` template function in `Taskfile.yml` |
| `jq` >= 1.7 | Homebrew, `modules/base.nix` | the evaluation JSON every read task consumes |
| GitHub Actions `uses:` versions | `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` | never written from memory |
