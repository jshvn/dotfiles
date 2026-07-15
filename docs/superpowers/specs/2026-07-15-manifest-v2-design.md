# Manifest Schema v2 — Design

Date: 2026-07-15
Status: Draft for review (revised after two-agent adversarial review; feature
accounting and array style added after operator review)

## Problem

The v1 manifest model works but carries avoidable cognitive load, and its
sharp edges all trace to one decision: `defaults.toml` is a mergeable
manifest. That forces:

- A merge-semantics contract (deep-merge maps, replace arrays, EXCEPT
  `extra_packages` which unions per-sub-array) that consumes a third of
  `docs/MANIFEST.md` and five golden fixtures.
- A required-fields drift guard that makes machines redeclare everything
  defaults could supply — the inheritance and the guard fight each other.
- Silent feature-flag typos: the unknown-key whitelist admits `features.*`
  wholesale, so a misspelled flag is neither warned nor errored; it just
  never applies.
- Default-on flags (`claude-marketplace`, `repo-auto-update`) that machines
  must override with explicit `= false`, the only place boolean noise
  appears in machine files.
- No way to see, from a machine file, which flags exist and which this
  machine deliberately lacks — the answer requires mentally diffing
  against `defaults.toml`.

Independent accumulated warts:

- Three package-declaration shapes: bundles write `[packages.brew]
  formulae=`, machines write `[packages.brew.extra_packages]`, and the
  non-brew buckets (`vscode`/`cargo`/`uv`/`npm`) use a third convention
  (same path everywhere). Casks require `{ name }` wrapper objects.
- Dead `verify` metadata on formula/cask objects (obsoleted by the
  `brew info --json=v2` verify model) and the `__bare`-lifting jq in
  `resolver.zsh` that exists only to let those objects win dedupe.
- `packages.brew.bundles` is a misnomer — bundles now carry vscode/cargo/
  uv/npm buckets too.
- 1Password cross-field rules hardcode identity names (`personal|work`) in
  `resolver.zsh`; the Linux spec's `server` identity escapes them only by
  not being named that.
- `identity.git` / `identity.ssh` are always the same value in practice
  (three machines, three matched pairs; the overlay dirs pair 1:1).

## Decisions

| Decision | Choice |
|----------|--------|
| Inheritance | None. A machine file is self-contained. `manifests/defaults.toml` is deleted; merge semantics are deleted with it. |
| Flag vocabulary | `manifests/features.toml` registry: every valid flag with description and optional `platforms` constraint. Unknown name anywhere = error. |
| Feature accounting | Total accounting. Each machine declares `[features] enabled = [...]` and `disabled = [...]`; together they must partition the registry's flags exactly. A flag whose `platforms` excludes the machine's os is *inapplicable*: it must appear in NEITHER list (it cannot be on, and listing it in `disabled` would falsely claim the machine "deliberately lacks" something it structurally cannot have) — an inapplicable flag in either list is a hard error. A flag in neither list (when applicable), or in both, is a hard error at `task setup`. Adding a flag to the registry therefore forces an explicit decision on every machine — a new flag can never be silently off (this replaces both v1's default-on flags and the earlier draft's pure opt-in, whose forgotten-flag silent-off risk the adversarial review flagged). Consequence to accept: changing a machine's `os`, or adding/removing a flag's `platforms` constraint, retroactively changes which flags every affected machine must account for — surfaced as a clear error at the next `setup`, never silently. |
| Identity | Single `identity = "<name>"` scalar, expanded to git+ssh by the resolver. Overlay files stay filesystem-validated; no identity registry. This removes the (never-used) ability to express `git = personal, ssh = work`. |
| 1Password flags | `one-password-ssh` / `one-password-signing` remain ordinary feature flags. 1Password availability is a machine/host capability, not an identity property — deriving it from identity would force minting parallel identities (`personal-no-1p`) the day a personal identity lands on a machine without 1Password. |
| Identity/1Password consistency | The v1 cross-field rule survives but loses its hardcoded names. Each identity overlay declares its own capability with an explicit sentinel comment: `# capability: one-password-ssh` in the ssh overlay, `# capability: one-password-signing` in the git overlay. The resolver greps for those exact sentinels; an identity carrying a capability sentinel requires the matching flag `enabled`. Declared metadata colocated with the overlay — filesystem-driven, no central enum, `none`/`atium`/`server` simply omit the sentinel. Chosen over grepping the overlay's *functional* lines (`IdentityAgent`, `op-ssh-sign`): both adversarial reviewers flagged that content-sniffing as fragile — it silently stops enforcing if the socket path is refactored, `Include`d out, or renamed upstream. A sentinel exists to be matched and won't drift for an unrelated reason. |
| Package shape | One `[packages]` table, identical in bundle files and machine files. A machine's extras are an inline anonymous bundle. Bare strings everywhere except `mas` (`{ id, name }` — the id is unavoidable). `verify` metadata is dropped. |
| Bundle selection | `bundles = [...]` moves inside `[packages]` (it selects packages across all managers, not just brew). Bundles themselves stay — see Out of scope for the considered-and-rejected fold-into-machines alternative. |
| Array style | Multi-element arrays in `manifests/**/*.toml` are written one element per line (trailing comma allowed). Empty and single-element arrays may stay inline. Enforced by a new lint rule (LINT-13) so the style survives future edits. |
| Claude addons | `[claude] addons = [...]` unchanged from v1 (consumed by `install/claude-addons.zsh` via `.claude.addons`). |
| resolved.json | Contract unchanged except one key: `schema_version` is NOT emitted (v1 leaks it into the output via the merge pass-through; nothing consumes it). `disabled` never appears in output — it is validation-only; disabled flags materialize as `false` exactly as v1 emitted them. Verified by a normalized golden diff (below). Zero consumer churn. |
| Unknown keys | Error, not warning. Resolver and manifests version together in one repo; there is no cross-version skew for warn-only forward-compat to serve. |
| schema_version | `2` in manifest files. Resolver rejects anything else. Not copied to resolved.json. |

## Schema by example

`manifests/machines/personal-laptop.toml`:

```toml
schema_version = 2

[machine]
description = "Josh's personal MacBook -- Apple Silicon, primary dev machine"
os = "darwin"           # {darwin, linux}
arch = "arm64"          # optional; carry forward any v1 platform.arch verbatim; else uname -m backfills
identity = "personal"

[features]
enabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "repo-auto-update",
  "ghostty",
  "jgrid-net",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-spotlight",
  "macos-screenshots",
  "macos-security",
  "macos-appearance",
  "macos-display",
]
disabled = [
  "server-include",
]

[packages]
bundles = [
  "dotfiles",
  "cli",
  "dotfiles-gui",
  "dev",
  "productivity",
  "apps",
]
# node: the ecc Claude addon's hooks invoke the `node` binary directly.
formulae = ["node"]
casks = [
  "cloudflare-warp",
  "discord",
  "dropbox",
  "nvidia-geforce-now",
  "proton-drive",
  "proton-mail",
  "protonvpn",
  "whatsapp",
]

[claude]
addons = [
  "ecc",
  "superpowers",
]
```

`manifests/machines/atium.toml` — the disabled list is long, and that is
the point: the machine file itself answers "which flags exist and which
does this machine deliberately not have" without consulting anything else:

```toml
schema_version = 2

[machine]
description = "Mac atium -- mostly-headless Mac server"
os = "darwin"
identity = "atium"

[features]
enabled = [
  "repo-auto-update",
  "macos-security",
  "ghostty",
]
disabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "jgrid-net",
  "server-include",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-spotlight",
  "macos-screenshots",
  "macos-appearance",
  "macos-display",
]

[packages]
bundles = [
  "dotfiles",
  "cli",
  "dotfiles-gui",
]
casks = [
  "appcleaner",
  "cloudflare-warp",
  "docker-desktop",
  "dropbox",
  "miniconda",
]
```

`manifests/features.toml` (registry — mechanical extraction of the flag
comments in v1 `defaults.toml`; must cover EVERY v1 flag or the golden
migration diff fails on feature-map key presence):

The registry has exactly 15 flags (the v1 `defaults.toml [features]`
set). Their `platforms` values, stated exhaustively so the implementer
guesses nothing:

| Flag | platforms |
|------|-----------|
| one-password-ssh | `["darwin"]` (1Password SSH agent socket is macOS-app-provided today; the Linux spec keeps servers off 1Password entirely) |
| one-password-signing | `["darwin"]` (same rationale — signing routes through the same macOS 1Password app) |
| claude-marketplace | none |
| repo-auto-update | none |
| ghostty | none (config is portable) |
| jgrid-net | none |
| server-include | none (the Linux spec's headless-server git-include path is the one place this is *for*; do NOT darwin-lock it) |
| macos-dock, macos-finder, macos-input, macos-spotlight, macos-screenshots, macos-security, macos-appearance, macos-display | `["darwin"]` each |

```toml
[one-password-ssh]
description = "link 1Password SSH agent config; agent socket in .zprofile"
platforms = ["darwin"]

[one-password-signing]
description = "git commit signing via 1Password op-ssh-sign"
platforms = ["darwin"]

[repo-auto-update]
description = "fast-forward the dotfiles repo from its remote before install"

[macos-dock]
description = "gates os/defaults/dock.zsh + macos:defaults:dock"
platforms = ["darwin"]

[ghostty]
description = "gates shell/aliases/ghostty.zsh + ghostty config link"

# ... remaining flags per the table above
```

(Note: the earlier draft's example darwin-locked only `one-password-ssh`
and left `server-include` implicitly darwin-locked. Both were wrong — the
table above is authoritative: 1Password signing is darwin-locked *with*
ssh, and `server-include` is the deliberately-portable flag.)

Bundle files keep their layout; only the table header and cask shape change:

```toml
# manifests/bundles/productivity.toml
[packages]
casks = [
  "raycast",
  "standard-notes",
]
mas = [
  { id = 441258766, name = "Magnet" },
  { id = 904280696, name = "Things3" },
]
```

## Design by component

### 1. Resolver (`install/resolver.zsh`)

Deleted:

- Pass 1 yq deep-merge (`. * .` ireduce) — no second source to merge.
- The `__bare`-lifting formulae dedupe jq — formulae are bare strings.
- The `personal|work` hardcoded cross-field case statements (replaced by
  the overlay-content rule below).
- The unknown-key whitelist/warning machinery (replaced by strict errors).
- `--defaults` test flag (no defaults file). A `--registry <path>` flag is
  added, overriding the `features.toml` path exactly as the existing
  `--shared-dir` overrides the bundles directory (test-only, documented in
  `--help` as not-for-production, same class as `--shared-dir`). Fixtures
  that exercise features-registry validation each ship a minimal
  `features.toml` and are run with `--registry $fix/features.toml`; the
  harness falls back to the real `manifests/features.toml` when a fixture
  ships none. This keeps `_invalid-unaccounted-feature` and friends from
  having to enumerate all 15 production flags (which would make every
  unrelated fixture brittle against registry growth).

Validation (all hard errors at `task setup` / `manifest:audit`):

- `schema_version == 2`.
- `machine.description` non-empty; `machine.os` in `{darwin, linux}`;
  `machine.arch` optional in `{arm64, x86_64}`.
- `machine.identity`: overlay files exist under both
  `identity/git/identities/` and `identity/ssh/identities/`.
- Identity/1Password consistency, via overlay sentinel comments: if the
  identity's ssh overlay contains `# capability: one-password-ssh`,
  `one-password-ssh` must be in `enabled`; if its git overlay contains
  `# capability: one-password-signing`, that flag must be in `enabled`.
  The sentinel strings live in one place in the resolver with a comment
  naming the contract. (Stage B adds these sentinels to the `personal`
  and `work` overlays; `atium`/`none` omit them.)
- `features`: every name in `enabled` and `disabled` exists in
  `features.toml`; no name appears in both; no duplicates within either;
  every registry flag applicable to `machine.os` (its `platforms`, when
  declared, contains the os) appears in exactly one of the two lists —
  the error for an unaccounted flag names the flag and both remedies;
  every `enabled` flag's `platforms` (when declared) contains
  `machine.os`.
- `packages.bundles`: non-empty, includes `dotfiles`, every name has a
  `manifests/bundles/<name>.toml`; each bundle's `platforms` (when
  declared) contains `machine.os`.
- `packages.*` arrays: bare strings only, except `mas` entries which
  require both `id` (integer) and `name`.
- `claude.addons`: every name has `manifests/claude-addons/<name>.toml`.
- Any key outside the schema, at any level: error naming the key path.

Emission — resolved.json keeps the v1 contract minus `schema_version`:

- `schema_version`: not emitted. v1 leaks `schema_version: 1` into the
  output via the merge pass-through; no consumer reads it.
- `meta.description` <- `machine.description`.
- `platform.os` / `platform.arch` <- `machine.os` / `machine.arch`
  (arch backfilled via `uname -m` as today).
- `features` <- boolean map materializing EVERY registry flag:
  `enabled` -> `true`, `disabled` or platform-exempt -> `false`. The
  `disabled` list itself never appears in output. Explicit
  materialization is required — consumers both truthy-test
  (`{{if index .MANIFEST.features "x"}}`) and string-compare
  (`test "{{index ...}}" != "true"` in `taskfiles/repo.yml:26`); a
  missing key renders `<no value>`, which happens to behave but only by
  accident. No consumer iterates the map or depends on key absence
  (verified).
- `identity.git` / `identity.ssh` <- both from `machine.identity`.
- `packages.brew.bundles` <- `packages.bundles` (output path keeps the v1
  name; see Out of scope).
- `packages.brew.extra_packages.{formulae,casks,mas}` <- union of each
  bucket across included bundles (in declared order) + the machine's
  inline `[packages]`, deduped (strings by value, `mas` by `.id`), last
  wins. Casks are re-wrapped as `{ name }` objects on output to preserve
  the contract (compose-brewfile reads `.name`).
- `packages.{vscode,cargo,uv,npm}` <- same union, same output paths.
- `claude.addons` <- as declared.

One union rule replaces v1's per-shape semantics: concat sources in order,
dedupe, last occurrence wins.

### 2. Operator surface

- `task features:show` (new, fits the domain-first `<domain>:<verb>`
  grammar): joins the registry with the active machine's resolved
  features and prints one line per flag — name, enabled/disabled,
  description. The at-a-glance runtime complement to the in-file
  accounting; trivial jq over `features.toml` + resolved.json. Add
  `features` to the pipe-separated `task <domain>:show` line in the
  Diagnostics section of the root `default:` banner (alongside
  `manifest | claude | claude-addons | hostname`). NOTE: this is a
  documentation convention, NOT a LINT-08 requirement — LINT-08 only
  scans colon-free top-level task names, so a colon'd `features:show`
  never trips it regardless. `status: [false]` on the task, matching
  every other `<domain>:show` (LINT-03a precedent).
- `manifest:show` / `manifest:audit` / `setup` / `test:manifest`
  unchanged in name and role.

### 3. Files touched beyond `manifests/` and the resolver

Code (verified: no other code reads the TOML sources — every other
consumer reads resolved.json, whose contract does not change):

- `Taskfile.yml`: `DEFAULTS_TOML` var deleted; the `MANIFEST_JSON`
  empty-stub fallback is unchanged; root banner gains `features:show`.
- `taskfiles/manifest.yml`: the `manifest:resolve` mtime check swaps
  `defaults.toml` for `features.toml` as a freshness source;
  `manifest:validate` file-existence checks likewise.
- `taskfiles/features.yml` (new): `features:show`.
- `taskfiles/lint.yml`: new LINT-13 — multi-element arrays in
  `manifests/**/*.toml` span one element per line. Implementation note
  (load-bearing): mikefarah yq's `line()` returns 0 for ALL TOML nodes
  (verified; the same limitation is already documented at
  `install/resolver.zsh:323-329`, which is why unknown-key line numbers
  use a `ggrep` heuristic, not yq). So LINT-13 CANNOT use yq line-span.
  Implement on raw file text: `ggrep -nE '=[[:space:]]*\[[^]]*[^][:space:]]'`
  finds any `key = [ ... <non-empty> ... ]` with content after the
  opening bracket on the same line; an array that legitimately spans
  lines has nothing but whitespace/comment between `[` and end-of-line.
  A single-element inline array (`formulae = ["node"]`) is exempt by
  counting commas: flag only when the same-line bracket content contains
  a top-level comma. Inline `{ id, name }` mas objects: their commas are
  inside braces, so match on commas outside `{...}` only, or (simpler)
  exempt any line whose bracket content contains `{`. Ship a worked
  command in the rule body; do not hand the implementer a yq filter.
  Catalogue row added to `CLAUDE.md`. Scope note: LINT-13 lands in
  stage A (schema-independent), but `manifests/test/**` fixtures are not
  reshaped to v2 until stage B — so stage-A LINT-13 must EXCLUDE
  `manifests/test/` (the exclusion is removed, and fixtures conform, in
  stage B). `manifests/defaults.toml` needs no exemption: all its arrays
  are empty or single-element, which the rule already exempts.
- `taskfiles/test.yml`: the numeric-fixture loop (inline yq merge of
  `defaults.toml + machine.toml`) is deleted with the merge itself; the
  typed-fixture loop drops `--defaults` and, where a fixture ships its own
  `features.toml`, adds `--registry $fix/features.toml` (see below); the
  `_run_warning_fixture` helper and `_warn-*` loop (~30 lines) are
  deleted — no warning fixtures remain in v2.
- `install/compose-brewfile.zsh`: functionally untouched; gains one
  comment mapping `packages.brew.extra_packages` to its true meaning
  (all packages, bundles union machine-inline) since the authoring
  format no longer contains that name.
- Untouched: `taskfiles/packages.yml`, `taskfiles/identity.yml`,
  `taskfiles/macos.yml`, `taskfiles/links.yml`, `taskfiles/claude*.yml`,
  `taskfiles/repo.yml`, `taskfiles/hostname.yml`,
  `install/claude-addons.zsh`, everything under `shell/` and `os/`.
- LINT-10/-11 unaffected; no existing lint rule references manifest paths
  (verified).

Docs (the blast radius is wider than MANIFEST.md — these all carry live
"how to add a feature/flag" instructions pointing at `defaults.toml
[features]`):

- `docs/MANIFEST.md` rewritten (merge-semantics section deleted).
- `CLAUDE.md`: the Manifest Model keystone table and opening paragraph
  (they describe defaults inheritance as current architecture), the
  "Where to Add Things" rows for features/packages/aliases, the lint
  catalogue (LINT-13), and the Don't-Do list. Add explicit escape-hatch
  prose: inline `[packages]` entries in a machine file are one-off
  extras; anything shared across machines belongs in a bundle (the
  `extra_packages` name used to carry this meaning; now prose must).
- READMEs referencing `defaults.toml`: `install/README.md` (its
  resolver.zsh description names the deleted file), `shell/README.md`,
  `os/README.md`, `identity/README.md`, `claude/README.md`,
  `configs/README.md`, `configs/{tlrc,eza,ghostty,motd}/README.md`,
  `manifests/*/README.md`.
- `docs/MACHINES.md` examples.

### 4. Fixtures and test assets

- `manifests/test/shared/{dotfiles,extbundle,util}.toml` use the v1
  `[packages.brew]` headers and must be rewritten to the v2 `[packages]`
  shape (they are consumed by the typed-* loop via `--shared-dir`).
- Deleted: fixtures `01`–`05` (pure merge semantics — no merge to test)
  and `_warn-unknown-key` (unknown keys are errors now).
- Kept, reshaped to v2: `_invalid-bad-identity`,
  `_invalid-bundle-typo`, `_invalid-bundles-no-dotfiles`,
  `_invalid-missing-bundles`, `_invalid-missing-desc`,
  `_invalid-missing-schema-version`, `_invalid-wrong-schema-version`,
  `_invalid-identity-without-opssh`, `_invalid-identity-without-opsign`
  (the consistency rule survives in overlay-derived form).
- Replaced, not reshaped: `typed-02-formulae-dedup` and
  `typed-05-bare-dedup` exist to test the object-beats-bare-string
  precedence that v2 deletes; their replacements test plain last-wins
  dedupe across bundles + machine.
- Changed trigger, not just reshaped: `_invalid-bad-os` currently rejects
  `os = "linux"`, but v2 widens the enum to `{darwin, linux}` so `linux`
  becomes VALID. Change its trigger value to `os = "windows"` and update
  `expect.txt` to the new out-of-enum message wording.
- New: `_invalid-unknown-feature` (typo'd name in either list),
  `_invalid-unaccounted-feature` (registry flag in neither list),
  `_invalid-feature-both-lists`, `_invalid-unknown-key` (top-level and
  nested), `_invalid-platform-feature` (darwin-only flag enabled on a
  linux machine), `_invalid-mas-shape`.

### 5. Interaction with the Linux server spec (2026-07-14)

Sequencing: **Linux lands first.** The Linux work is additive at existing
seams and delivers operator value now; v2 is internal cleanup. The only
overlap is ~10 lines of cross-field rules (macos-*/1Password require
darwin) that the Linux spec adds and v2 later replaces with registry
`platforms` metadata — cheap throwaway, not worth serializing a schema
rewrite in front of running servers.

When v2 lands after Linux:

- The `platform.os` enum widening is already done.
- The Linux spec's hand-written cross-field rules collapse into
  `platforms = ["darwin"]` entries on the macos flags and the
  1Password flags in `features.toml`.
- `features.claude` becomes one more registry entry; `dotfiles-gui` /
  `apps` / `productivity` bundles gain `platforms = ["darwin"]` so a
  Linux machine selecting them fails at setup. Compose-time filtering of
  `mas`/`cask`/`vscode` lines for `os = linux` is still needed for
  platform-neutral bundles like `dotfiles` that carry darwin-only entry
  types.
- Platform exemption keeps Linux machine files honest: darwin-only flags
  need not (and cannot) be accounted on a linux machine, so its
  `disabled` list stays short and meaningful.

## Migration plan

Three stages (A, B independently revertible; C a later mechanical
follow-up), each with its own golden check.

Golden-check mechanics (applies to every stage): the comparison is
capture-then-compare within ONE working tree, NOT a git branch/worktree
diff. Before editing anything in a stage, run
`resolver.zsh --machine <m> --stdout | jq -S 'del(.schema_version)'` for
all three machines and save to a scratch path OUTSIDE the repo
(e.g. `$TMPDIR/golden-<m>-pre.json`). After the stage's edits land, re-run
the (now-modified) resolver against the (now-modified) files and diff its
`jq -S .` output against the saved baseline. Once `defaults.toml` and the
v1 resolver are gone, the baseline exists only in those saved files — so
capturing first is mandatory, not optional.

Stage A — package-shape cleanup (stays on schema v1):

1. Casks to bare strings in all TOMLs; drop `verify`/object-formula
   support and the `__bare` jq from the resolver; rewrite
   `typed-02`/`typed-05` fixtures. Apply the one-element-per-line style
   and land LINT-13 here (it is schema-independent).
2. Golden check: `resolver --machine <m> --stdout | jq -S` identical
   before/after for all three machines.

Stage B — schema v2:

1. Add `manifests/features.toml` (every v1 flag, exactly — key-set parity
   is asserted by the golden diff).
2. Rewrite `install/resolver.zsh` to read v2 + emit the v1 resolved.json
   contract minus `schema_version`.
3. Rewrite the three machine files and six bundle headers +
   `manifests/test/shared/*.toml`.
4. Golden migration diff, normalized: for each machine,
   `resolver --stdout | jq -S 'del(.schema_version)'` on the v1 checkout
   must equal `resolver --stdout | jq -S .` on the v2 branch. Assert the
   features key set equals the registry key set.
5. Delete `defaults.toml`; update `Taskfile.yml` / `manifest.yml` /
   `test.yml` per section 3; add `features:show`; refresh fixtures per
   section 4.
6. Rewrite `docs/MANIFEST.md`; sweep `CLAUDE.md` and the section-3 README
   list. Per repo convention, no doc or comment may narrate the v1->v2
   migration; this spec and the commit messages carry that story.

## Error handling

- Every validation failure names the offending key path and, for enum-ish
  failures (features, bundles, identities), lists the valid set — same UX
  as v1's identity errors. The unaccounted-flag error names the flag, its
  registry description, and both remedies (add to `enabled` or
  `disabled`).
- Unknown keys error with the full path.
- The resolver still fails closed: no resolved.json is written from an
  invalid manifest.

## Security

The resolver consumes operator-authored TOML and compiles it into
`resolved.json`, which drives `brew bundle` (Ruby DSL), symlink creation,
and Claude addon installers — all during `task install` with no
diff-review gate. Because `repo-auto-update` fast-forwards the public repo
from its remote immediately before install, "the TOML is trusted" is not
strictly true: a compromised or malicious upstream commit that alters a
manifest, bundle, or addon file is acted on automatically. This is the
git-pull analog of the repo's own "no curl-to-shell without checksum" bar,
and the following are load-bearing, not optional. Stage A carries the two
code fixes (both apply to the current v1 resolver and compose script; v2
inherits them).

- **Package-name injection (CRITICAL, pre-existing).**
  `install/compose-brewfile.zsh` emits each package name inside a
  single-quoted Ruby string with no escaping (lines 131/134/143-152), and
  the `mas` id fully unquoted (line 137). A formula value like
  `node', system('...') #` produces executable Ruby that `brew bundle`
  runs. The v1 resolver validates package *shape* but never *characters*.
  Fix, at `validate_manifest` time: every package name
  (formulae/casks/mas.name/vscode/cargo/uv/npm) must match a strict
  allow-list (`^[A-Za-z0-9][A-Za-z0-9._@+/-]*$`); `mas.id` must be a JSON
  number, not merely present. Defense in depth: escape embedded single
  quotes in `compose-brewfile.zsh` on emit even though validation blocks
  them. This removes the "functionally untouched" claim for
  compose-brewfile — it gets a validation-partnered escape fix.
- **Path traversal on TOML-sourced names (MEDIUM, pre-existing).** Only the
  machine *name* has a regex guard (`MACHINE_NAME_RE`). Bundle names,
  identity value, and claude-addon names are concatenated into paths
  (`SHARED_DIR/${bn}.toml`, `identity/<kind>/identities/${val}`,
  `manifests/claude-addons/${addon}.toml`) with existence checks only.
  `bundles = ["../evil"]` or `addons = ["../evil"]` escapes the reviewed
  directory; the addon case is worse because `install/claude-addons.zsh`
  already `eval`s commands from the addon TOML, so traversal breaks its
  stated "only trust files under manifests/claude-addons/" containment.
  Fix: generalize `MACHINE_NAME_RE` into one shared name-regex helper and
  apply it to bundle names, the identity scalar, and addon names before
  every existence check, in both `resolver.zsh` and `claude-addons.zsh`.
  The v2 Validation list (section 1) gains one name-shape check per class.
- **Non-issues, noted so a future contributor doesn't regress them.** The
  `yq ".${parent} | has(...)"` interpolation uses only compile-time
  constant field paths, never TOML values — do not parameterize it from
  TOML. The `emit_unknown_key_warnings` leaf-regex guard and the fixture
  harness's copy-with-EXIT-trap cleanup are already sound. The
  overlay-content 1Password derivation greps fixed literal patterns (not
  TOML values), so it is injection-safe once the identity value is
  shape-guarded above — its only weakness is the correctness ceiling noted
  in the design (a novel 1Password integration path the literals miss).

## Testing

- The normalized golden diff (migration plan, both stages) is the primary
  net — it proves zero behavior change for existing machines.
- Fixture suite per section 4 covers the new validation classes.
- `task lint` gains LINT-13; existing rules unaffected (verified — none
  reference manifest paths).

## Out of scope

- Roles/profiles or any machine-file inheritance ("workstation implies
  macos flags") — re-litigating the per-machine-explicitness decision
  requires new evidence, not this spec.
- Deriving the `disabled` list instead of authoring it. Considered (the
  resolver already knows `registry − enabled − inapplicable`): it would
  cut the O(machines) edits per new flag and remove the rubber-stamp
  surface a long `disabled` block invites. Rejected because the authored
  list is the operator-requested property — a machine file that answers
  "which flags exist, which are on, which are deliberately off" without
  running a command or consulting the registry. The forced-decision
  guarantee (a new registry flag can never be silently off) holds either
  way; the difference is purely whether the "off" set is visible in the
  file or only via `task features:show`. This spec keeps it in the file.
  The accepted cost: adding a flag is an N-machine edit, and the golden
  diff / `manifest:audit` catch an unaccounted flag but not an operator
  who typed a flag into `disabled` meaning `enabled` (uncatchable intent).
  If the per-flag edit burden ever bites, revisit — `features:show`
  already exists as the derived-view fallback.
- Folding bundles into machine files. Considered: with bundles gone, the
  resolver loses its union pass and each machine file is the complete
  package list. Rejected: the two laptops share an identical six-bundle
  selection and atium shares three of them — inlining duplicates those
  lists per machine, and every later addition must be repeated in N
  files, with silent divergence (add on one laptop, forget the other) as
  the failure mode. That is horizontally the same drift class the repo's
  "single source of truth, single pipeline" decision exists to kill, and
  the mandatory `dotfiles` baseline bundle is the strongest case: it is
  the guarantee every machine gets the core toolchain without every
  machine file re-listing it. Bundles also become the platform-gating
  unit under the Linux spec. Machine-file verbosity is not the binding
  constraint; cross-machine consistency is.
- Renaming resolved.json output paths within stages A/B
  (`packages.brew.extra_packages` is a misnomer in the compiled artifact
  too). Doing it inside B would forfeit the normalized golden diff that is
  the migration's safety net. It is NOT abandoned: it is committed as
  stage C — a mechanical path-rename (jq rename in the resolver's emit +
  sed across the ~4 resolved.json consumers in `compose-brewfile.zsh` and
  taskfiles), with its own before/after golden diff proving the rename is
  behavior-neutral. Stage C is where the compose-brewfile mapping comment
  from stage B is deleted (the name finally tells the truth). Kept out of
  A/B, not out of the plan.
- Per-machine feature parameters (values beyond on/off).
- YAML/JSON authoring formats, schema files for editors.
- Changing bundle granularity or names.
