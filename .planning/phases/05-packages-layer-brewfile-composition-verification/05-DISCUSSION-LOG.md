# Phase 5: Packages Layer — Brewfile Composition + Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-15
**Phase:** 05-packages-layer-brewfile-composition-verification
**Areas discussed:** Bundle layout & membership, extra_packages format, Verify defaults & overrides, Verify failure policy & install gate

---

## Initial Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Bundle layout & membership | Flat vs nested directory + content split across core/gui/dev/ops/personal | ✓ |
| extra_packages format | Flat array vs typed buckets vs lookup vs raw heredoc | ✓ |
| Verify defaults & overrides | Cask app-name derivation + multi-binary formula handling | ✓ |
| Verify failure policy & install gate | Hard-fail vs warn-and-continue; audit strictness; composed Brewfile cache | ✓ |

User selected all four (multi-select).

---

## Area 1a: Bundle Directory Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Flat: packages/<purpose>.rb | Matches CLAUDE.md + ROADMAP success #3; future package managers get top-level dirs | ✓ |
| Nested: packages/brew/<purpose>.rb | Matches REQUIREMENTS.md PKGS-01 verbatim; contradicts CLAUDE.md | |

**User's choice:** Flat layout (Recommended option).
**Notes:** REQUIREMENTS.md PKGS-01 needs an edit (its `packages/brew/<purpose>.rb` text). Captured as a planner action item in CONTEXT.md `<domain>`.

---

## Area 1b: Bundle Membership Threshold

First presented a 5-bundle "purpose" split (core / gui / dev / ops / personal) with three pre-shaped options (recommended, no-ops, six-bundle). User selected **"Other split"** and asked:

> "why not just use the same approach as in current v1? personal, server, work all allow me to add each individual brew package/cask/wahtever to that machine profile. cant we maintain that flexibilty in the new model?"

Claude clarified that v2's `extra_packages` already provides per-machine flexibility — what was being replaced was the `Brewfile-<profile>.rb` filename pattern (named-by-machine), not the underlying capability. Re-presented as a threshold question:

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal bundles, heavy extras | Only core.rb + gui.rb ship as bundle files; everything else in per-machine extra_packages | ✓ |
| Mid-bundles + extras | core + gui + dev as bundles; ops/personal as bundles dropped; light extras | |
| Original 5-bundle split + extras | core/gui/dev/ops/personal as bundles per ROADMAP success #3 verbatim | |
| Other approach | User describes a different framing | |

**User's choice:** Minimal bundles, heavy extras (closest to v1 spirit).
**Notes:** Drives several downstream consequences: ROADMAP success criterion #3 needs amending (5-bundle enumeration → 2-bundle minimum); PROJECT.md "per-purpose bundles in `packages/brew/<purpose>.rb` (`core`, `gui`, `dev`, `ops`, `personal`)" needs amending; per-machine TOMLs grow substantially (each machine declares its full cask + MAS list in `extra_packages`). All captured in CONTEXT.md `<domain>` "Required ROADMAP / REQUIREMENTS edits."

---

## Area 2: extra_packages Format

| Option | Description | Selected |
|--------|-------------|----------|
| Typed buckets | Three explicit sub-tables: formulae / casks / mas; MAS apps carry id + name; verify lives inline as object field | ✓ |
| Flat array with type prefix | "brew:hugo", "cask:slack", "mas:441258766:Magnet" — single list, compact, trickier verify comments | |
| Bare strings, resolver looks up type | Cleanest manifest; requires brew info lookup, slow / network-dependent / no MAS shape | |
| Embed raw Brewfile lines | Heredoc Ruby in TOML — max flexibility, ugly and hard to validate | |

**User's choice:** Typed buckets (Recommended).
**Notes:** Schema migration affects `defaults.toml` + 4 machine manifests. Current `extra_packages = ["docker-desktop"]` (personal-laptop) migrates to `[packages.brew.extra_packages] casks = [{ name = "docker-desktop", verify = "Docker" }]`. Captured in CONTEXT.md D-03.

---

## Area 3a: Cask Verify Default

| Option | Description | Selected |
|--------|-------------|----------|
| Title-case each dash-separated word | visual-studio-code → Visual Studio Code.app heuristic + overrides for non-conformers | |
| Require explicit '# verify:' on every cask | No derivation; every cask line carries # verify: <Name>; safer | ✓ |
| Use brew info --json=v2 at verify time | Always-correct; network-dependent, slower, no offline verify | |

**User's choice:** Explicit on every cask.
**Notes:** Doubles authorship line-cost (every cask gets a comment / verify field), but verify pass never lies. CONTEXT.md D-04 + suggested LINT-09 to enforce structurally (lint rejects cask lines missing `# verify:` comment).

---

## Area 3b: Formula Verify

| Option | Description | Selected |
|--------|-------------|----------|
| Default bin == formula; override with '# verify: <bin>' | Matches VRFY-01 spec verbatim; multi-bin formulas pick one representative | ✓ |
| Multiple bins per formula, list all in comment | Noisier; brew is atomic so multi-bin check doesn't add real safety | |
| Always use `brew list <formula>` instead of command -v | Violates VRFY-01 spec; misses PATH/shellenv breakage | |

**User's choice:** Default bin == formula; override with `# verify: <bin>` (Recommended).
**Notes:** Override examples for core.rb: git-delta → delta, grep → ggrep, openssh → ssh, coreutils → gsha256sum, bottom → btm, trippy → trip. CONTEXT.md D-05.

---

## Area 4a: Verify Failure Policy at Install Gate

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail | Any missing bin/.app exits non-zero with full check/cross table | ✓ |
| Hard fail with --no-verify escape | Same default with CLI escape hatch | |
| Warn-and-continue | Verify becomes diagnostic noise; defeats VRFY-04 | |

**User's choice:** Hard fail (Recommended).
**Notes:** No escape hatch — `task install` is idempotent end-to-end so the recovery path is "fix manifest or upstream cask, re-run." CONTEXT.md D-10.

---

## Area 4b: packages:audit Default Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Non-blocking by default, --strict exits non-zero | Matches ROADMAP success #5 verbatim; CI gate via flag | ✓ |
| Always non-zero on drift | Noisier; every brew install probably-temporary fails CI | |
| Always exit 0 | No CI integration point | |

**User's choice:** Non-blocking by default, `--strict` for CI (Recommended).
**Notes:** Scope: `brew leaves` for formulae (top-level only), `brew list --cask`, `mas list`. CONTEXT.md D-11.

---

## Area 4c: Composed Brewfile Cache + Status

| Option | Description | Selected |
|--------|-------------|----------|
| $XDG_CACHE_HOME/dotfiles/Brewfile + brew bundle check status | Single canonical path; atomic mktemp+mv; --no-upgrade sub-second on converged | ✓ |
| $XDG_STATE_HOME/dotfiles/Brewfile-<machine> | Per-machine suffix; reuses state path | |
| Don't compose — run brew bundle per bundle file | Avoids composition step; more tasks; status: AND across files | |

**User's choice:** $XDG_CACHE_HOME/dotfiles/Brewfile + `brew bundle check` (Recommended).
**Notes:** Status block uses TWO conditions: (1) composed file exists, (2) `brew bundle check --no-upgrade` exits 0. Template vars only (LINT-02). CONTEXT.md D-08 + D-09.

---

## Claude's Discretion

Areas where the planner has flexibility (captured in CONTEXT.md `<decisions>` "Claude's Discretion" subsection):

- MAS CLI location (`core.rb` default; could move to `gui.rb` if server cost feels wrong)
- MAS app name sanity-check methodology (live `mas list` lookup before committing extras)
- Final ordering of `task install` cmds (where `packages:install` and `packages:verify` slot in)
- Composer language choice (`install/compose-brewfile.zsh` vs inline `cmds:` block)
- Header banner format in the composed Brewfile
- LINT-09 ship-with-P5 vs follow-up plan
- MAS-on-server hypothetical
- `tap` directive handling (concatenate-verbatim; no special handling needed)
- `1password-cli` placement (cask vs formula in core.rb)

## Deferred Ideas

Captured in CONTEXT.md `<deferred>`:

- **Owned by later phases:** `task validate` composition (P8), `task links:reconcile` (P8), `docs/CUTOVER.md` (P8 DOCS-08), `docs/MIGRATION.md` v1→v2 (P8 DOCS-05), `brew bundle cleanup` destructive mode (PERF-V2), v1 `install/Brewfile*.rb` deletion (P8), LINT-09 if not shipped in P5
- **Future hardening (out of v1):** Brew version pinning, npm/cargo/pip manifests, per-machine `tap` declarations, pre-install snapshot for rollback, CI gate wiring for `packages:audit --strict`, `DRY_RUN=1` mode, MAS auth bootstrap
- **Open questions:** `1password-cli` cask-vs-formula form, `zoom`'s installed app name (`zoom.us` per v1 observation), whether `formulae = []` extras will ever be non-empty
