# Machine Reference

## What This Is

Per-machine prose the TOML manifests cannot express: purpose, hardware
narrative, role, and special handling notes. Declarative state -- feature
flags, identity selection, packages -- lives in
`manifests/machines/<name>.toml` and is authoritative; run
`task manifest:show -- --machine <name>` to see the resolved result.

Nothing here enumerates packages or flags. That duplication drifts, and the
manifest already answers it in one file.

## personal

- Purpose: primary personal Mac, daily driver for personal projects and
  personal AI/CLI work.
- Hardware: Apple Silicon (`arm64`, declared explicitly in `[machine].arch`).
- Role: full GUI + dev + personal feature set. Day-to-day use is
  personal-project development, dotfiles iteration, and Claude Code work.
- Special handling: the personal git/ssh identity is wired here, with SSH
  auth and commit signing flowing through the 1Password agent.

## work

- Purpose: work-issued MacBook carrying the work git/ssh identity.
- Hardware: Apple Silicon or Intel -- arch is detected by the resolver via
  `uname -m` because `[machine].arch` is absent.
- Role: primary work development machine. Commits and remote access carry
  the work attribution.
- Special handling: the main divergence from personal is the identity; the
  toolchain is a subset of personal's. The personal network (the `jgrid-net`
  aliases and the `*.jgrid.net` SSH host blocks) does not apply here.

## ci

- Purpose: the GitHub Actions runner profile.
- Hardware: the `macos-latest` runner image; `[machine].arch` is declared
  `arm64`.
- Role: drives the full operator pipeline (bootstrap, setup, install,
  validate, test, lint, converged re-install) on a fresh runner. It is a real
  machine manifest rather than a special case in the workflow, so CI
  exercises the same resolver path as a laptop.
- Special handling: the no-op `none` identity, no GUI, no AI surface (the ai
  flag is off). If a change makes CI need a package, that is a signal about
  the repo's own toolchain, not about CI.
