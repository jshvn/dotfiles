---
name: verifying-dotfiles-changes
description: Use after changing anything in this dotfiles repo - maps each change type to the task commands that prove convergence; five-tier testing model; one-check rule.
---

# Verifying Dotfiles Changes

Run the narrowest check that can fail, then the relevant aggregate.

| You changed | Run | Proves |
|---|---|---|
| Any taskfile | `task lint` | LINT rules pass, banner drift caught |
| Machine/base/feature TOML | `task setup -- "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/machine")" && task manifest:audit` | resolver validates, resolved.json fresh |
| Package declarations | `task diff` then `task install && task packages:audit` | preview is what you expected, Brewfile converges, no drift |
| Symlink entries (links.yml) | `task diff` then `task install && task links:audit` | preview lists the intended links, they exist and point into the repo |
| Shell files (.zsh) | `task lint && task test && exec zsh` | parse-check, smoke tests, live shell loads |
| claude/settings.d fragments | `task diff` then `task install && task claude:audit` | preview shows the intended key changes, live settings.json matches the composed artifact |
| Claude addon TOMLs | `task install && task claude-addons:audit` | addon verify probes pass |
| os/defaults | `task install`, then log out/in for domains that need it | defaults applied |

Aggregates: `task diff` (preview, read-only), `task validate` (installation state),
`task test` (all smoke tests), `task audit` (all-domain drift, read-only).

## The five-tier model

1. Static lint (`task lint`) -- syntax and repo rules, no side effects
2. Validate (`task validate`) -- is the machine in its declared state
3. Reconcile (`task install`) -- converge; a second run must be a fast no-op, so a re-run
   that does work is itself a failed check
4. Smoke (`task test`) -- behavior probes
5. System (`task audit`) -- cross-domain drift detection

Each tier catches a different drift class; "looks installed but isn't" and
"symlink-soup-after-refactor" are the two this repo has been burned by.

`task diff` sits before tier 3: it compares the materialized build artifacts in
`$XDG_STATE_HOME/dotfiles/build/` against the live system, so it answers "what would install
change" without changing anything. Reach for it whenever an install is about to do more than
you expect.

One more check the staging discipline makes available: after a converged `task install`,
`git status --short` must be empty. The repo tree holds source only, so anything showing up
there is either a real edit or a generated file that escaped into the tree.

## The one-check rule

Non-trivial logic ships with one runnable check that fails if the logic breaks -- an
assert-based self-check or a smoke test wired into `task test`. No frameworks, no fixtures.
A change without its check is unfinished.

Interactive convenience functions (`shell/functions/*.zsh`, `shell/aliases/*.zsh`) are
exempt, even when they contain parsing or formatting logic: `task lint` parse-checks them,
and running the function once in a live shell is their verification. Do not write smoke
tests for them or wire them into `task test`. The one-check rule targets pipeline logic --
resolver, compose, hooks, audits -- where a silent break corrupts machine state rather
than one prompt's output.
