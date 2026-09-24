# Decisions, Scope, and Constraints

Locked decisions with rationale. The point is to prevent re-litigation; revisit only with
new evidence. Referenced from CLAUDE.md.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Symlinks + TOML manifests over Nix | Nix conflicts with go-task lock-in, slows AI iteration; manifest layer captures the declarative win without language overhead. |
| Self-contained per-machine manifests + a feature registry | Picked clarity (per-machine, no inheritance) over DRY (tags); a machine file records every flag it wants and deliberately lacks, while `manifests/features.toml` keeps the flag vocabulary in one place. |
| Explicit machine selection at setup | Hostname-based detection has bitten us; explicit selection beats clever auto-detect. |
| macOS-only | All target machines are macOS laptops; avoids cross-platform complexity until a real Linux machine enters scope. |
| Keep alanpeabody-based prompt; reject Starship | The existing `theme.zsh` is small, fast, and not on life support; Starship would be a behavior change with no problem to solve. |
| Bootstrap without curl-to-shell, except Homebrew's own installer | Removes supply-chain risk on every fresh install; the Homebrew installer is the one accepted exception, consent-gated and HTTPS-only (`docs/SECURITY.md`). |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself. |
| `task install` is the canonical entry; update path runs through the same task | Prevents the "add a package to update path, forget install, fresh machine breaks" drift class — single source of truth, single pipeline. |
| Five-tier testing: static lint, validate, reconcile, smoke, system | Each tier catches different drift; without verify+reconcile we'd ship "looks installed but isn't" or "symlink-soup-after-refactor". |
| Curated top-level surface (`install / setup / validate / test / lint / audit / diff / report`, plus `show`) + domain-first `<domain>:<verb>` diagnostics | Audited every exposed task; one grammar (pick a domain, pick a verb); bare verbs aggregate; lint enforces banner drift via LINT-08. |
| Separate realize from activate; the repo tree holds source only | Compute the whole desired state into `$XDG_STATE_HOME/dotfiles/build/` before touching the system, so `task diff` is a file comparison rather than a recomputation, and no generated file is tracked. |
| atium moved to `jshvn/jgrid.net` on 2026-09-23 | Its runtime needs (tunnel pair, secrets, nightly switch, healthcheck) were the NixOS common layer's; nix-darwin gave them a launchd backend. This repo is laptops-only. |
| No Spaces / Mission Control speed tweak; `macos-animations` covers AppKit only | Measured on macOS 27.0 (2026-09-22): the Dock renders the ~1.2 s desktop slide itself and exposes no duration key. The legacy Dock keys (`expose-animation-duration`, `springboard-*-duration`, `workspaces-swoosh-animation-off`) exist in no macOS 27 binary, and `com.apple.WindowManager AnimationSpeed`, `ExposeSpringResponse`, `ExposeSpringDampingRatio` and `com.apple.dock mission-control-transition` all time identical to stock. Do not re-add them; revisit only if a later 27.x adds a key. |
| AI tooling config lives in `jshvn/ai`, not here | Claude Code is one tool among several and its config had grown a resolver key, two taskfiles, a TOML addon runner and machine-local links inside the working tree. Dotfiles keeps a one-flag seam (`ai`, `[ai] profile / ref`) that clones the repo at a pinned ref and runs its `task install`; per-machine variation is a profile in that repo. ECC was dropped in the same move. |

## Out of Scope

Explicit boundaries with reasoning. The point is to prevent re-litigation; revisit only with
new evidence.

- **Linux / Windows / WSL** — macOS-only is a deliberate simplification. All target machines
  are macOS laptops. Platform-aware directory split, apt/dnf manifests, and Linux bootstrap
  branch are deferred until a real Linux machine enters scope.
- **Servers** — every server, Mac or not, is a jgrid.net fleet host.
- **Nix / home-manager** — evaluated; conflicts with go-task lock-in, slows AI iteration loop,
  Homebrew still needed for macOS GUI apps via `nix-darwin.homebrew` escape hatch. The
  declarative-manifest goal is already achieved via TOML at lower cost.
- **chezmoi / stow / yadm** — adds a tool dependency that overlaps with go-task; doesn't
  solve the manifest problem.
- **Starship prompt** — the existing alanpeabody-based `theme.zsh` is small, fast, and not on
  life support. Starship would be a behavior change with no problem to solve.
- **fish / nu / bash** — zsh is the chosen shell.
- **Replacing go-task** — locked.
- **Hostname-based machine detection** — burned us before (the legacy `.zprofile`
  literal-hostname check). Explicit `task setup -- <machine>` only.
- **Inline profile branching in shared files** — behavior varies only through manifest-driven
  feature gates.
- **Auto-detection of identity / capabilities** — the manifest is the source of truth; no
  clever inference at runtime.

## Performance and Security Constraints

- **Performance target** — interactive shell cold start under 500ms (the
  `task shell:startup-time` budget); `task install` re-run
  under 30s on a converged machine (includes `brew update` network round-trip; under 5s
  without network).
- **Security** — no curl-to-shell except the consent-gated Homebrew installer
  (`docs/SECURITY.md`); no secrets in repo; public SSH keys only.
- **Idempotency** — every install task has a working `status:` check; re-running
  `task install` is a fast no-op.

## Tooling Versions

| Tool | Minimum | Reason |
|------|---------|--------|
| `yq` (mikefarah) | 4.52.1 | Full TOML read/write roundtrip; TOML-to-JSON for the resolver |
| `go-task` | 3.37 | `ref:` keyword + `fromJson` template function for structured vars |
| `jq` | 1.7 | Sorted-key output (`-S`) for stable fixture diffs; `--argjson` |
