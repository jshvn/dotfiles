# os

macOS configuration: per-concern `defaults write` scripts plus shell
registration. Each concern is feature-gated via `../manifests/machines/<name>.toml`;
`task macos:apply-defaults` orchestrates the apply path; `task macos:validate`
asserts current state matches the in-script expected values. macOS-only; the
flat layout (no platform subdirectories) reflects that single-platform scope.

## Purpose

Eight `defaults/<concern>.zsh` sourced libraries declare a single tuple-array
source of truth per concern (`(domain, key, expected_value, write_type)`
rows). Each library exposes `apply_<concern>` and `verify_<concern>`, which
delegate to the shared `_apply_defaults` / `_verify_defaults` loop in
`defaults/_apply_verify.zsh` (apply runs `defaults write`; verify reads back,
printing `check`/`cross` via `../install/messages.zsh` and returning non-zero
on any drift). The taskfile sources the script for both write and read paths,
so the array is the contract for both sides.

`shell-registration.zsh` is the always-on sibling (no feature gate): it adds
Homebrew zsh to `/etc/shells` and `chsh`es the user to it. The task's
`status:` block uses the `{{.BREW_ZSH}}` template variable (not a `$BREW_ZSH`
shell variable, which is empty in status context), so a converged machine
skips the re-apply.

## Key files

- `defaults/dock.zsh` -- Dock keys (gated on `macos-dock`)
- `defaults/finder.zsh` -- Finder keys (gated on `macos-finder`; shared
  with `../shell/aliases/finder.zsh` as same-flag-two-consumers --
  any machine that wants the Finder aliases also wants the Finder
  defaults applied, and vice versa)
- `defaults/input.zsh` -- Keyboard / trackpad keys (gated on `macos-input`)
- `defaults/screenshots.zsh` -- Screen capture keys (gated on `macos-screenshots`)
- `defaults/security.zsh` -- Security / privacy keys (gated on `macos-security`)
- `defaults/appearance.zsh` -- System appearance + icon/widget style (gated on `macos-appearance`)
- `defaults/display.zsh` -- Built-in display "More Space" HiDPI scaling
  (gated on `macos-display`; drives the `defaults/display-mode.swift` helper)
- `defaults/spotlight.zsh` -- Disable the Spotlight Cmd+Space binding to free
  it for Raycast (gated on `macos-spotlight`)
- `defaults/_apply_verify.zsh` -- Shared `_apply_defaults` / `_verify_defaults`
  loop that every concern library delegates to (not feature-gated; sourced).
- `shell-registration.zsh` -- `/etc/shells` + chsh (always-on, no gate;
  `status:` uses the `{{.BREW_ZSH}}` template var, not `$BREW_ZSH`)
- `hostname.zsh` -- `apply_hostname` / `verify_hostname` plus state-file
  helpers, consumed by `../taskfiles/hostname.yml`

## Adding a pattern

- **A new defaults concern.** Create `defaults/<concern>.zsh` with the
  `<CONCERN>_DEFAULTS` tuple array (rows of
  `(domain, key, expected_value, write_type)`) plus `apply_<concern>` and
  `verify_<concern>` functions -- one source of truth per concern.
  Register a `[macos-<concern>]` block in `../manifests/features.toml`
  (`description` plus `platforms = ["darwin"]`), and list the key in every
  machine's `[features]` enabled or disabled array. Add the concern to the parameterized
  `macos:apply-defaults:concern` task in `../taskfiles/macos.yml` (sources
  the script; gates on the feature flag via
  `index .MANIFEST.features "macos-<concern>"` -- kebab-case keys
  require the `index` form). Wire it into the `macos:apply-defaults`
  aggregator's `cmds:` list. Wire the verify call into the
  `macos:validate` task body. Add it to the `[features] enabled` array on
  machines that want it (and `disabled` elsewhere) in
  `../manifests/machines/<name>.toml`.
- **A new key inside an existing concern.** Append one 4-tuple to the
  existing `<CONCERN>_DEFAULTS` array; both apply and verify pick it up
  automatically -- the array is the contract. For `-currentHost`-scoped
  keys (per-host plists under `~/Library/Preferences/ByHost/`), append to
  the `<CONCERN>_DEFAULTS_CURRENTHOST` array instead and let the apply /
  verify loop call `defaults -currentHost write|read`.
- **A note on expected LINT-05 portability warnings.** The `defaults
  read/write` and `dscl` calls in this directory will trip the LINT-05
  portability check (`../taskfiles/lint.yml`). LINT-05 is warn-only
  (`exit 0`); these warnings are expected and intentional for the
  macOS-only code paths in this directory.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics
- `../manifests/features.toml` -- feature-flag registry (where `macos-*`
  keys are declared)
- `../CLAUDE.md` -- project conventions (flat directories, one concept per
  file, status-block templating rules)
