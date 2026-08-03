# Decisions, Scope, and Constraints

Locked decisions with rationale. The point is to prevent re-litigation; revisit only with
new evidence. Referenced from CLAUDE.md.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Symlinks + TOML manifests over Nix | Nix conflicts with go-task lock-in, slows AI iteration; manifest layer captures the declarative win without language overhead. |
| Self-contained per-machine manifests + a feature registry | Picked clarity (per-machine, no inheritance) over DRY (tags); a machine file records every flag it wants and deliberately lacks, while `manifests/features.toml` keeps the flag vocabulary in one place. |
| Explicit machine selection at setup | Hostname-based detection has bitten us; explicit selection beats clever auto-detect. |
| macOS-only | All target machines are macOS (laptops + Mac servers); avoids cross-platform complexity until a real Linux machine enters scope. |
| Keep alanpeabody-based prompt; reject Starship | The existing `theme.zsh` is small, fast, and not on life support; Starship would be a behavior change with no problem to solve. |
| Bootstrap without curl-to-shell | Removes supply-chain risk on every fresh install. |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself. |
| `task install` is the canonical entry; update path runs through the same task | Prevents the "add a package to update path, forget install, fresh machine breaks" drift class — single source of truth, single pipeline. |
| Five-tier testing: static lint, validate, reconcile, smoke, system | Each tier catches different drift; without verify+reconcile we'd ship "looks installed but isn't" or "symlink-soup-after-refactor". |
| Curated top-level surface (`install / setup / validate / test / lint / audit / diff`) + domain-first `<domain>:<verb>` diagnostics | Audited every exposed task; one grammar (pick a domain, pick a verb); bare verbs aggregate; lint enforces banner drift via LINT-08. |
| Separate realize from activate; the repo tree holds source only | Compute the whole desired state into `$XDG_STATE_HOME/dotfiles/build/` before touching the system, so `task diff` is a file comparison rather than a recomputation, and no generated file is tracked (a `/model` toggle can no longer dirty the working tree). |

## Out of Scope

Explicit boundaries with reasoning. The point is to prevent re-litigation; revisit only with
new evidence.

- **Linux / Windows / WSL** — macOS-only is a deliberate simplification. All target machines
  (laptops + Mac servers) are macOS. Platform-aware directory split, apt/dnf manifests, and
  Linux bootstrap branch are deferred until a real Linux machine enters scope.
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
- **Inline profile branching in shared files** — replaced by manifest-driven feature gates.
- **Auto-detection of identity / capabilities** — the manifest is the source of truth; no
  clever inference at runtime.

## Performance and Security Constraints

- **Performance target** — interactive shell cold start under 200ms; `task install` re-run
  under 30s on a converged machine (includes `brew update` network round-trip; under 5s
  without network).
- **Security** — bootstrap verifies install integrity; no curl-to-shell without checksum;
  no secrets in repo; public SSH keys only.
- **Idempotency** — every install task has a working `status:` check; re-running
  `task install` is a fast no-op.

## Tooling Versions

| Tool | Minimum | Reason |
|------|---------|--------|
| `yq` (mikefarah) | 4.52.1 | Full TOML read/write roundtrip; TOML-to-JSON for the resolver |
| `go-task` | 3.37 | `ref:` keyword + `fromJson` template function for structured vars |
| `jq` | 1.7 | Sorted-key output (`-S`) for stable fixture diffs; `--argjson` |
