---
name: jshvn-verifying-dotfiles-changes
description: Use after changing anything in this dotfiles repo - maps each change type to the task commands that prove convergence; the tier model; one-check rule.
---

# Verifying Dotfiles Changes

Run the narrowest check that can fail, then the relevant aggregate. `git add -A` first:
`task check` evaluates the git tree, and an untracked file is invisible to it.

| You changed | Run | Proves |
|---|---|---|
| A machine, profile, module, concern or app `.nix` | `task check` | every machine and profile still evaluates; an unaccounted switch, a redundant package or a bundled extension fails here, naming itself |
| Package lists (`packages.*`, `provided.*`, base) | `task diff`, then `task install && task audit` | the preview is what you expected; brew bundle converges; nothing undeclared remains |
| `dotfiles.links`, `shell.aliases`, `shell.env` | `task diff`, then `task install && task validate && task audit` | the closure diff lists the intended links; each resolves into the checkout; no orphans |
| Shell files (`shell/`, an `aliases.zsh`, an `env.zsh`) | `task lint && task test && exec zsh` | parse-check, the live shell loads, the plugin markers hold |
| `system/<concern>.nix` | `task install && task validate` | every defaults key reads back (log out and in for the domains that need it) |
| `apps.claude-code.{profile,ref}` | `task install && task validate` | the checkout is at the ref, the ai repo's own validate passes |
| `Taskfile.yml`, `tasks/*.zsh`, `tasks/tests/*` | `task lint && task test` | the rules and the smoke tests |
| `.github/workflows/ci.yml` | push a branch, open a PR | the same `check`, `lint`, `test` with Docker |

Aggregates: `task diff` (preview, read-only), `task validate` (installation state),
`task test` (smoke tests and the negative evaluations), `task audit` (drift beyond the
declaration, read-only).

## The tier model

1. Static lint (`task lint`): syntax and repo rules, no side effects.
2. Evaluate (`task check`): every machine and profile to its system closure, in the pinned
   image, no Mac needed.
3. Validate (`task validate`): is the machine in its declared state.
4. Reconcile (`task install`): converge; a second run must change nothing (`task diff` shows
   no closure change and `brew bundle check` is satisfied), so a re-run that does work is
   itself a failed check.
5. Smoke (`task test`): behavior probes.
6. System (`task audit`): what is on the machine beyond the declaration, known CVEs.

Each tier catches a different drift class; "looks installed but isn't" and
"symlink-soup-after-refactor" are the two this repo has been burned by.

`task diff` sits before tier 4: a closure diff against the running generation, then what brew
bundle would add. Reach for it whenever an install is about to do more than you expect.

After a converged `task install`, `git status --short` must be empty (the `result` symlink is
ignored). The repo tree holds source only.

## The one-check rule here

The rule itself is `jshvn-one-check-rule`. In this repo the check is a probe in
`tasks/tests/negative.sh` (a declaration rule, proven by breaking it) or a smoke test under
`tasks/tests/` wired into `task test`.

Interactive convenience functions (`shell/functions/*.zsh`, any `aliases.zsh`) are exempt,
even when they contain parsing or formatting logic: `task lint` parse-checks them, and running
the function once in a live shell is their verification. Do not write smoke tests for them.
The rule targets pipeline logic -- validate, audit, checkout, the scanners -- where a silent
break corrupts machine state rather than one prompt's output.
