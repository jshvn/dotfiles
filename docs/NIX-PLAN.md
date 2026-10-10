# Nix Plan

The agreed target for moving the laptops from the TOML-manifest / `resolver.zsh` / go-task
pipeline onto nix-darwin, with every decision taken so far. Written 2026-10-10 for a session
that starts with no context. Status: design agreed, spike verified, nothing migrated.
`docs/README.md` says plans do not live here; Josh asked for this one explicitly. Delete it
when the migration lands or is dropped, and fold any surviving decision into `DECISIONS.md`.

This is dotfiles v3. The work happens on branch `dotfiles-rewrite-v3` and the first release is
tag `v3.0.0` (tags are semver, latest `v2.10.0`; `release.yml` turns a pushed tag into a GitHub
release).

A verified copy of the whole target tree is at `$XDG_STATE_HOME/dotfiles/nix-spike/`
(machine-local, not in git). Start from it rather than retyping; everything below describes
that tree.

## Decisions

1. **Nix is the evaluator and activator, nothing else.** Homebrew installs every formula,
   cask, Mac App Store app and VS Code extension, rolling, against the existing
   `/opt/homebrew`. No nixpkgs packages, no nix-homebrew, no `environment.systemPackages`.
   The lock file pins only nix-darwin's own inputs. The Nix installer is the official
   multi-user one (the one with the `vifs` step; atium used it).
2. **The terminal looks and behaves exactly as today.** Homebrew zsh is the login shell, the
   repo's own `.zshenv` / `.zprofile` / `.zshrc` / `.zlogin` / `.zlogout`, theme, MOTD,
   functions and aliases are what runs. nix-darwin's zsh wiring is off
   (`programs.zsh.enable = false`), so Apple's `/etc/zshrc` and `/etc/zprofile` are untouched.
   Layout and plumbing may change; appearance may not.
3. **No concept called "features".** Five option namespaces, each one kind of thing:
   `system`, `apps`, `identity`, `repo`, `packages` (table below).
4. **One directory per application, owning everything about it**: the install, the config
   files, the shell integration, and any system setting that exists only for that app.
   The rule for what is an app: anything with configuration attached to its install.
   Anything merely installed is a package name in the profile.
5. **Every optional switch has no default.** A profile sets each `system.<concern>`,
   `apps.<name>.enable`, `shell.jgrid-net` and `repo.devToolchain` to true or false, or
   evaluation fails naming the option. This is the old "every flag accounted for" rule,
   enforced by the module system instead of `validate_manifest`.
6. **The redundancy rule stays.** A profile may not list a formula or cask that base or an
   enabled app already provides, nor a VS Code extension the app bundles; an assertion fails.
7. **Taps are derived**, never listed: a tap-qualified formula (`hashicorp/tap/terraform`)
   implies its tap. `homebrew/brew-vulns` is the one bare tap, declared in `base.nix`.
8. **A real identity turns 1Password on, and nothing else does.** Josh only uses 1Password.
   `identity = "personal" | "work"` sets `apps."1password".enable`; `"none"` clears it. The
   option is `readOnly`; a profile never sets it. No capability flags, no sentinel assertions.
9. **Every link goes through one registry.** `dotfiles.links` maps a home-relative path to a
   path under the checkout. home-manager installs each as an out-of-store symlink, so an edit
   is live without a switch, and `task validate` reads each one back. Shell gates are links
   decided at switch time: an enabled app's or concern's `aliases.zsh` is linked into
   `$XDG_STATE_HOME/dotfiles/aliases.d/`, login-env fragments into `env.d/`; the startup files
   source those two directories. The runtime gate helpers, `resolved.json` and the jq parse at
   startup are gone.
10. **No operator functionality regresses.** Every public task of v2 has a v3 counterpart or
    a stated reason to go (inventory below). Read-back validation covers every domain the old
    tiers covered, from one evaluation of the declaration.
11. **One machine file per physical laptop, named after it**, importing a profile. The
    hostname moves from the machine-local state file into the repo. Selection stays explicit:
    `task setup -- <name>` writes the state file the Taskfile reads; nothing infers the
    machine from the live hostname. The two machines are `lerasium` (this MacBook Pro) and
    `harmonium` (the second personal MacBook). The work laptop is out of scope for v3.0.0;
    `profiles/work.nix` is kept and the flake check evaluates it under a synthetic machine.
12. **`task install` always fast-forwards the checkout** before the switch, then refreshes the
    antidote bundles. There is no per-machine auto-update knob.
13. **Live editing survives.** `shell/`, `identity/`, every app config and alias file are
    linked out of the store. Only what an activation step runs (`display-mode.swift`, the
    `apps/claude-code/` directory, `tasks/messages.zsh`) is copied into the store with its
    generation.
14. **CI becomes the container.** `nix flake check`, `nix fmt -- --ci` and the negative suite
    run inside the pinned `nixos/nix` image on a Linux runner; every machine and every profile
    is fully evaluated in about two minutes. `tasks/lint.zsh` and the smoke tests need zsh,
    jq and GNU grep as `ggrep`; run them on the same runner after installing those, or skip
    them in CI and keep them as `task lint` / `task test` on a Mac.
15. **VS Code `settings.json` stays unmanaged for now.** It lives under
    `~/Library/Application Support/Code/User`, not XDG; `apps/vscode/` is where it would go.

## What this does and does not buy

The spike started from "I think I am missing system settings from the repo". That gap is a
missing list of keys, not a missing tool: nix-darwin has typed options for everything found
unmanaged (key repeat, tap-to-click, three-finger drag, menu-bar clock, Control Center, login
items, Fn key, Touch ID for sudo), and so does the current tuple model, one line each. The
Spotlight half of "Cmd+Space goes to Raycast" is already declared and applied on lerasium.
The Raycast half cannot be declared by anything: Raycast 2.7.3 keeps its hotkey in its own
database, `com.raycast.macos` has no hotkey key, and only Raycast cloud sync carries it.

What nix-darwin buys: about 8,700 lines of resolver, taskfiles, manifests and fixtures become
about 900 lines of Nix plus four operator scripts; the three resolver rules become module-system
errors; non-defaults state (login shell, `/etc` files, launchd agents, PAM Touch ID) is native;
generations give rollback; CI is a two-minute Linux evaluation; one mental model with jgrid.net.

What it costs: sudo on every switch; a switch takes 30 s to 2 min instead of seconds; a second
toolchain on disk (`/nix`, holding only nix-darwin); `DECISIONS.md` currently rejects Nix twice
and must be rewritten in the first PR.

## Operator surface: v2 task to v3

| v2 | v3 | What changed |
|---|---|---|
| `setup -- <name>` | `task setup -- <lerasium|harmonium>` | same state file |
| `install` | `task install` | `git pull --ff-only`, `darwin-rebuild switch`, `antidote update --bundles` |
| `validate` (manifest, identity, links, packages, shell, macos, hostname, ai) | `task validate` | one evaluation piped to `tasks/validate.zsh`; every old check carried over except manifest schema, which the module system replaces |
| `audit` (manifest, packages, vulns, links) | `task audit [-- --strict]` | `brew bundle cleanup` dry run, the same tap/trust scan, the same orphan scan, `brew vulns` |
| `diff` (packages, links) | `task diff` | closure diff against the running generation, then `brew bundle check --verbose`; link changes appear in the closure diff |
| `show`, `manifest:show`, `features:show`, `hostname:show`, `ai:show` | `task show` | the evaluated `dotfiles` namespace as JSON |
| `report` | gone | it summarised a converged Mac for the CI job summary; CI no longer runs on a Mac, and `show` is the declaration's record |
| `test` (10 suites) | `task test` | kept and moved to `tasks/tests/`: shell-startup, links-audit, packages-trust, repo-sync, ai-checkout; manifest fixtures become `negative.sh` (the three rules); gone with their subjects: packages-declared, brewfile-compose, report, lint fixtures |
| `lint` (13 rules) | `task lint` | kept in `tasks/lint.zsh`: zsh parse (07), `set -euo` (04), banner (12), hardcoded prefix (10); plus `nix fmt -- --ci`; gone with their subjects: status vars (02), safe-link (03), portability (05), banner parity (08), kebab access (11), array style (13) |
| `shell:startup-time` | `task shell:startup-time` | same 500 ms budget |
| `shell:antidote-update`, `repo:sync` | inside `install` | |
| `hostname:set`, the `sethostname` function | edit `machines/<name>.nix`, switch | the function goes; it would drift from the declaration |
| `links:audit -- --remove` | gone | `audit` lists orphans; remove by hand, which is a one-time job after migration |
| `macos:apply-defaults:refresh-ui` | nix-darwin | it restarts Dock, Finder and friends itself after writing defaults |
| `manifest:resolve/set`, `packages:compose`, `links:install*`, `identity:install*`, `macos:install*`, `helpers:*` | gone | internal pipeline steps the module system and home-manager replace |
| (new) | `task check` | evaluate every machine and profile in the image |
| (new) | `task rollback` | the previous generation |

## Target tree

```
dotfiles/
├── flake.nix                 inputs: nixpkgs, nix-darwin, home-manager (26.05 line); checks every machine and profile
├── flake.lock
├── Taskfile.yml              the surface above; one SHAPE expression feeds show, diff, validate, audit
├── bootstrap.zsh             reduced: Homebrew consent gate + the official Nix installer (not yet written)
├── machines/                 one file per physical laptop
│   ├── lerasium.nix          hostname + `imports = [ ../profiles/personal.nix ]`
│   └── harmonium.nix
├── profiles/
│   ├── personal.nix          identity, every system concern, every optional app, shell/repo knobs, packages
│   └── work.nix              no machine imports it yet; the flake check evaluates it under a synthetic machine
├── modules/                  plumbing only, nothing a profile names directly
│   ├── default.nix           imports; dotfiles.checkout and dotfiles.links; the one user; Nix housekeeping
│   ├── packages.nix          packages / provided buckets, redundancy assertion, tap derivation
│   ├── base.nix              the unconditional formulae (no config attached) and the bare tap
│   ├── homebrew.nix          onActivation: autoUpdate, upgrade, cleanup
│   ├── identity.nix          identity enum; git and ssh links; turns 1Password on
│   ├── shell.nix             login shell, /etc/zshenv ZDOTDIR line, startup-file links, aliases.d / env.d
│   └── repo.nix              repo.devToolchain
├── system/                   macOS settings, one file per System Settings concern
│   ├── default.nix           imports
│   ├── dock.nix  input.nix  appearance.nix  screenshots.nix  animations.nix
│   ├── security.nix          GuestEnabled typed; ImageCapture ByHost key via home-manager
│   ├── display.nix           activation script running the Swift helper beside it
│   ├── display-mode.swift
│   └── finder/               a concern with shell integration is a directory
│       ├── default.nix
│       └── aliases.zsh
├── apps/                     one directory per application
│   ├── default.nix           imports
│   ├── 1password/            default.nix  agent.toml  env.zsh (SSH_AUTH_SOCK, linked into env.d)
│   ├── claude-code/          default.nix  checkout.zsh  repo-sync.zsh        (the jshvn/ai seam)
│   ├── conda/                default.nix  condarc
│   ├── dust/                 default.nix  config.toml  aliases.zsh
│   ├── eza/                  default.nix  theme.yaml          (base app: no enable option)
│   ├── ghostty/              default.nix  config  aliases.zsh
│   ├── herdr/                default.nix  config.toml
│   ├── raycast/              default.nix  random-email.zsh    (owns the Spotlight hotkey)
│   ├── tlrc/                 default.nix  config.toml         (base app: no enable option)
│   └── vscode/               default.nix                      (cask + the 28 bundled extensions)
├── tasks/                    what the Taskfile runs
│   ├── validate.zsh          read the whole declaration back from the live system
│   ├── audit.zsh             state beyond the declaration, known CVEs
│   ├── lint.zsh              the four zsh rules
│   ├── messages.zsh          check / cross / info / warn / error / success
│   ├── links-audit-scan.zsh  orphan detection (unchanged)
│   ├── packages-trust-scan.zsh  tap / trust drift (unchanged)
│   └── tests/                shell-startup  links-audit  packages-trust  repo-sync  ai-checkout  negative.sh
├── shell/                    unchanged except the two startup loops and the motd/ move
│   ├── .zshenv .zprofile .zshrc .zlogin .zlogout .zsh_plugins.txt theme.zsh
│   ├── aliases/              general dotfiles hardware networking jgrid   (shell-level topics only)
│   ├── functions/            unchanged; helpers/ keeps only _dotfiles_url_host.zsh
│   └── motd/                 motd_tron.txt motd_sysinfo.jsonc motd_jgrid.png (was configs/motd/)
└── identity/                 unchanged except agent.toml, which moved to apps/1password/

gone: install/ manifests/ taskfiles/ os/ configs/ .github/workflows/ci.yml (rewritten) docs/MANIFEST.md
```

Every top-level directory needs its README (repo rule); the spike tree has none.

## Option namespaces

| Option | Type | Set by | Meaning |
|---|---|---|---|
| `dotfiles.identity` | enum personal, work, none | profile | which git/ssh overlay is linked; implies 1Password |
| `dotfiles.system.<concern>` | bool, no default | profile | dock, finder, input, screenshots, security, appearance, display, animations |
| `dotfiles.apps.<name>.enable` | bool, no default | profile | raycast, ghostty, herdr, vscode, claude-code, conda, dust |
| `dotfiles.apps."1password".enable` | bool, readOnly | identity.nix | never set by a profile |
| `dotfiles.apps.raycast.freeCmdSpace` | bool, no default | profile | disable Spotlight hotkey 64 |
| `dotfiles.apps.vscode.extensions` | list of str, default [] | profile | this machine's extras beyond the bundled 28 |
| `dotfiles.apps.claude-code.{profile,ref,dir}` | str | profile | the jshvn/ai profile, ref and checkout path |
| `dotfiles.shell.jgrid-net` | bool, no default | profile | link the jgrid.net fleet aliases |
| `dotfiles.shell.{aliases,env}` | attrs name to path | apps, system, shell.nix | internal: what gets linked into aliases.d / env.d |
| `dotfiles.links` | attrs home path to checkout path | shell.nix, identity.nix, apps | internal: every symlink, installed by home-manager, read back by validate |
| `dotfiles.repo.devToolchain` | bool, no default | profile | linters, formatters, hyperfine |
| `dotfiles.packages.{formulae,casks}` | list of str | profile | free choices with no config attached |
| `dotfiles.packages.mas` | attrs name to id | profile | Mac App Store apps |
| `dotfiles.provided.{formulae,casks}` | list of str | base.nix, apps, repo.nix | internal: what the profile may not repeat |
| `dotfiles.checkout` | str | default | `/Users/josh/Git/personal/dotfiles`, the out-of-store link target |

Base apps (eza, tlrc) declare no option: `shell/` breaks without them, so no machine may
decline them. That is the existing base-tier rule restated.

## Mechanisms worth knowing before touching the code

- **A concern or app module declares its own option and its own config** (`options.dotfiles.
  system.dock = lib.mkOption { type = lib.types.bool; description = ...; }` then
  `config = lib.mkIf config.dotfiles.system.dock { ... }`). The registry is distributed; each
  file is the single source of truth for its concern.
- **One evaluation for every read.** The Taskfile's `SHAPE` is a Nix function applied with
  `nix eval --json <flake>#darwinConfigurations.<machine>.config --apply`. It returns
  `dotfiles` (the whole namespace), `defaults` (every `system.defaults` group, each wrapped in
  `tryEval` because nix-darwin keeps removed groups such as `alf` that throw when touched),
  `currentHost` (home-manager's ByHost keys), `brewfile` (nix-darwin's generated Brewfile,
  which exists only in the store), `taps`, `casks` and `hostName`. `homebrew.casks` and
  `homebrew.taps` are lists of records, so scripts read `.name`. The eval prints one
  `trace: Obsolete option ... expose-group-by-app` line, which is noise.
- **The validator** (`tasks/validate.zsh`) walks that JSON: XDG dirs, the ZDOTDIR line in
  `/etc/zshenv`, the machine state file, `scutil` hostname; every registered link resolves
  (`readlink -f`) to its checkout path; the keys directory holds only `.pub` files, git
  `user.email` under `~/git/<identity>` matches the overlay, `SSH_AUTH_SOCK` is the 1Password
  socket and `ssh-add -L` offers the identity's key; `brew bundle check` against the generated
  Brewfile, then every cask's `.app` artifacts exist under `/Applications`; the jshvn/ai
  checkout is at its ref and that repo's own `task validate` passes; every defaults key reads
  back (group mapped to its domain, bools as 1/0, numbers numerically), the display preset
  via the Swift helper, and hotkey 64 via the exported symbolic-hotkeys plist. It refuses
  empty input and exits 1 on any cross.
- **The audit** (`tasks/audit.zsh`): `brew bundle cleanup` without `--force` is a dry run
  whose "Would uninstall" sections list undeclared formulae, casks and extensions (its
  trailing "Would `brew cleanup`" cache section is not drift and is cut); the unchanged
  `packages-trust-scan.zsh` compares `brew tap` and `brew trust --json v1` with the declared
  taps; the unchanged `links-audit-scan.zsh` finds symlinks into the checkout that no
  `dotfiles.links` entry expects, scanning `~/.config`, `ZDOTDIR`, `~/.local/state/dotfiles`
  and `~/.ssh`; `brew vulns --brewfile` with severity high. Findings warn; `--strict` exits 1.
- **The two startup loops** are the only edits to `shell/` beyond the motd path:

  ```zsh
  # .zshrc, replacing the shell/aliases/ glob
  for file in "${XDG_STATE_HOME}/dotfiles/aliases.d/"*.zsh(-.N); do
      source "$file"
  done
  # .zprofile, replacing the resolved.json / jq block
  for file in "${XDG_STATE_HOME}/dotfiles/env.d/"*.zsh(-.N); do
      source "$file"
  done
  ```

  The moved alias files lost their `_dotfiles_require_feature` lines; `jgrid.zsh` lost its
  source-time gate. On every real machine the result is identical to today. The one
  theoretical difference: on a machine with an app off, its function is undefined rather
  than defined-and-refusing with the custom message. Josh accepted that.
- **nix-darwin writes a nested defaults value whole, never merging.** `AppleSymbolicHotKeys`
  holds every shortcut on the machine, so the Spotlight entry (64) stays a `-dict-add`
  activation script in `apps/raycast/default.nix`, followed by `activateSettings -u`.
  `CustomUserPreferences` would replace the whole 22-entry table with one entry.
- **nix-darwin has no `-currentHost` writes.** The ByHost `com.apple.ImageCapture
  disableHotPlug` goes through home-manager's `targets.darwin.currentHostDefaults`.
- **Three activation scripts run as the user** (`sudo -u josh`, because activation is root):
  the Raycast hotkey, `display-mode.swift apply`, and the claude-code checkout plus
  `task -d <dir> install`. The claude-code step references `${./.}` so the whole directory is
  in the store and `checkout.zsh` finds `repo-sync.zsh` beside it; `tasks/messages.zsh`
  arrives as `$MESSAGES`, with the checkout-relative path as the fallback when the script
  runs from the checkout (the tests do). `system.primaryUser = "josh"` is set; the username
  is hardcoded in the scripts (a spike shortcut; use `config.system.primaryUser`).
- **Homebrew cleanup.** The spike sets `homebrew.onActivation.cleanup = "uninstall"`, which
  the current pipeline does not do (`brew bundle install --upgrade`, no cleanup). The first
  switch on a real machine must run with `cleanup = "none"` and `task audit` read before
  turning it on. On lerasium today the audit already shows what would go: the VS Code
  extension `jshvn.title-buttons`, installed by hand and declared nowhere.
- **`sysadminctl -screenLock immediate`** needs the account password on a tty, which a switch
  does not have. It stays a one-time manual step per machine (as today). The guest account
  is the typed `loginwindow.GuestEnabled = false`, which nix-darwin writes to the system-level
  domain; today's script uses `sysadminctl -guestAccount off` for the same effect.
- **zsh traps found while building this**: `path` is the array tied to `$PATH`, so never use
  it as a variable name (it silently empties PATH); the `nixos/nix` image has no `sed`, so
  mutate files in checks with bash `${var//old/new}`; `nix fmt` needs `--tree-root` outside a
  git checkout.
- **nix-darwin issue 1866 is a mac-app-util bug**, not macOS 27 incompatibility. nix-darwin
  works on macOS 27 without mac-app-util. The earlier note that the laptops stayed on dotfiles
  because of 1866 was wrong; they stay by decision.

## File moves

| Today | Target | Edit |
|---|---|---|
| `shell/aliases/ghostty.zsh` | `apps/ghostty/aliases.zsh` | gate line removed |
| `shell/aliases/dust.zsh` | `apps/dust/aliases.zsh` | none |
| `shell/aliases/finder.zsh` | `system/finder/aliases.zsh` | three gate lines removed |
| `shell/aliases/jgrid.zsh` | stays | source-time gate removed; banner still names the deleted helper |
| `shell/functions/helpers/_dotfiles_feature.zsh`, `_dotfiles_require_feature.zsh` | deleted | `sethostname.zsh` mentions them; delete that function too (hostname is in the machine file) |
| `shell/aliases/dotfiles.zsh` | stays | its `update` alias runs `repo:sync` then `install`; becomes `task -d "$DOTFILEDIR" install` alone |
| `configs/<tool>/<file>` | `apps/<tool>/<file>` | none |
| `configs/motd/*` | `shell/motd/` | `shell/functions/motd.zsh` paths updated |
| `configs/raycast/random-email.zsh` | `apps/raycast/` | none; re-register the directory in Raycast |
| `identity/ssh/agent.toml` | `apps/1password/agent.toml` | none |
| `os/defaults/display-mode.swift` | `system/display-mode.swift` | none |
| `os/defaults/_apply_verify.zsh` and every `verify_*` | `tasks/validate.zsh` | one generic reader |
| `install/messages.zsh`, `links-audit-scan.zsh`, `packages-trust-scan.zsh` | `tasks/` | banners repathed |
| `install/ai-checkout.zsh`, `repo-sync.zsh` | `apps/claude-code/checkout.zsh`, `repo-sync.zsh` | messages sourced via `$MESSAGES` |
| `install/tests/{shell-startup,links-audit,packages-trust,repo-sync,ai-checkout}.zsh` | `tasks/tests/` | paths repathed; all five pass on the v3 tree |
| `os/defaults/<concern>.zsh` tuples | `system/<concern>.nix` | typed options where nix-darwin has them, else `CustomUserPreferences` |
| `manifests/machines/personal.toml`, `work.toml` | `profiles/personal.nix`, `work.nix` | `miniconda`, `raycast`, `dust` left the package lists (they are apps now) |
| `manifests/features.toml`, `base.toml`, `install/resolver.zsh`, `taskfiles/*`, `install/report.zsh`, `compose-brewfile.zsh` | gone | |

`dust` is an app with `enable` because work does not install it today but sourced its aliases
anyway; now the aliases only exist where the tool does.

## Verification done

Inside the pinned image (`nixos/nix:2.35.2@sha256:7a007c7664...`), via Apple `container`,
and on lerasium itself, 2026-10-10:

- `nix flake check`: `lerasium`, `harmonium`, and the `personal` and `work` profiles under a
  synthetic machine all evaluate to their system closures. Exit 0.
- `tasks/tests/negative.sh`: the three mutations (an app unaccounted, a provided cask listed
  again, a bundled extension listed again) each fail evaluation with the expected message.
- `tasks/lint.zsh`: clean over 56 zsh files; `nix fmt` applied to the tree (32 files).
- The five smoke tests pass against the v3 tree (shell-startup, links-audit, packages-trust,
  repo-sync, ai-checkout).
- `tasks/validate.zsh`, fed the lerasium declaration from the image: 83 checks pass,
  including the hostname, identity keys, `SSH_AUTH_SOCK`, `ssh-add -L`, `brew bundle check`,
  every cask's app artifact, the jshvn/ai checkout at `main` with its own validate, every
  defaults key, the ByHost key, the display preset and the hotkey. The crosses are exactly
  the migration delta: the 19 links that still point into v2 paths or do not exist yet
  (`configs/`, `aliases.d/`, `env.d/`, the two directory links) and the `/etc/zshenv` line,
  which v2 wrote with the expanded path and v3 writes with `$HOME`.
- `tasks/audit.zsh`: taps and trust clean, `brew vulns` clean; real drift reported: the
  undeclared VS Code extension `jshvn.title-buttons`, and stale per-file identity links from
  retired hosts (atium, server-1, server-2) that v3's directory links will supersede.
- `jq .dotfiles` on the same JSON is `task show`.

Re-run from the stash:

```sh
S="$XDG_STATE_HOME/dotfiles/nix-spike"
container run --rm --memory 4g -v "$S":/work -w /work \
  -e NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos/nix:2.35.2@sha256:7a007c766426c1877758ddc5cb87a965ac131fc78c582ce0083d922d51ae945c \
  sh -c 'nix flake check && SRC=/work bash tasks/tests/negative.sh'
```

Not verified: a real `darwin-rebuild switch` on any machine; the activation scripts;
`task validate` end to end with a local `nix` (the eval ran in the image, the script locally);
`task diff` and `task rollback`; the startup-time budget after the loop change.

## Migration order

All on branch `dotfiles-rewrite-v3`; the merge to master is tagged `v3.0.0`.

1. **Docs first.** Rewrite the two Nix rows in `DECISIONS.md` (the go-task objection is
   disproven by jgrid.net; the macOS 27 blocker was wrong), delete `docs/MANIFEST.md`, rewrite
   `MACHINES.md` for machine files, update `CLAUDE.md`, write the new READMEs (`machines/`,
   `profiles/`, `modules/`, `system/`, `apps/`, `tasks/`) and fix `shell/` and `identity/`
   READMEs (they describe `configs/` and the gates).
2. **Bring the stash in**; delete what the tree above lists as gone; purge every comment that
   describes the old system (`LINT-NN` citations in kept zsh, `resolved.json`,
   `_dotfiles_feature`, `configs/`, taskfile names) per the `jshvn-replacing-a-system` skill.
   `task check`, `task lint` and `task test` must pass before anything touches a machine.
3. **Record the baseline** on master before switching: `task validate` and `task audit`
   from the old pipeline, and `task links:audit` for the full list of existing links.
4. **Bootstrap lerasium.** Run the official multi-user Nix installer (it edits Apple's
   `/etc/zshrc` and `/etc/bashrc` to put `nix` on PATH, the one startup change). Move the
   hand-written `/etc/zshenv` aside: nix-darwin refuses to overwrite it (on lerasium it holds two ZDOTDIR
   lines, an unquoted v2 leftover above the quoted one). First switch with
   `cleanup = "none"`; read `task audit`; then `"uninstall"`.
5. **Prove appearance and state.** Same MOTD, prompt, `g`, Finder and jgrid aliases;
   `task validate` exits 0; `task audit` clean after removing the stale links it lists;
   `task shell:startup-time` within budget.
6. **Retire the old state**: `resolved.json`, `links.map`, `build/`, the hostname state file,
   the per-file identity links v3 replaces with directory links.
7. **CI**: replace the macOS pipeline job with an ubuntu job running the container commands
   (`check`, `nix fmt -- --ci`, `negative.sh`), plus `lint` and `test` if zsh, jq and `ggrep`
   are installed on the runner.
8. **harmonium**: confirm `uname -m`, repeat 4 to 6.
9. **Tag `v3.0.0`** on master after the squash merge.

## Deferred

- VS Code `settings.json` (Josh: leave it for now).
- The work laptop (Josh: ignore for now); `profiles/work.nix` waits for its machine file.
- `sysadminctl -screenLock immediate`: manual, once per machine.
- Replacing the hardcoded `josh` in activation scripts with `config.system.primaryUser`.
- `harmonium`'s `nixpkgs.hostPlatform` is assumed Apple Silicon; confirm before its switch.

## Conventions that carry over

- Executable zsh keeps `set -euo pipefail` and the three-label banner (Purpose / Depends on /
  Side effects); `tasks/lint.zsh` enforces both, plus `zsh -n` and the no-hardcoded-prefix
  rule (`# lint-allow: hardcoded-prefix` marks the dispatch sites).
- No AI attribution, no emojis, anywhere (hooks enforce both). Public keys only under
  `identity/ssh/keys/`.
- Machine identity is explicit (`task setup -- <name>`); never infer from hostname.
- Commit format `<type>(<scope>): <summary>`, squash merge to master.
- `ponytail:` marks an intentional shortcut and names its ceiling.
