# Machine Reference

## What This Is

Per-machine prose the TOML manifests cannot express: purpose, hardware
narrative, role, and special handling notes. Declarative state -- feature
flags, identity selection, packages -- lives in
`manifests/machines/<name>.toml` and is authoritative; run
`task manifest:show -- --machine <name>` to see the resolved result.

Nothing here enumerates packages or flags. That duplication drifts, and the
manifest already answers it in one file.

## personal-laptop

- Purpose: primary personal Mac, daily driver for personal projects and
  personal AI/CLI work.
- Hardware: Apple Silicon (`arm64`, declared explicitly in `[machine].arch`).
- Role: full GUI + dev + personal feature set. Day-to-day use is
  personal-project development, dotfiles iteration, and Claude Code work.
- Special handling: the personal git/ssh identity is wired here, with SSH
  auth and commit signing flowing through the 1Password agent.

## work-laptop

- Purpose: work-issued MacBook carrying the work git/ssh identity.
- Hardware: Apple Silicon or Intel -- arch is detected by the resolver via
  `uname -m` because `[machine].arch` is absent.
- Role: primary work development machine. Commits and remote access carry
  the work attribution.
- Special handling: the divergence from personal-laptop is the identity, not
  the toolchain. The personal-network identity does not apply here.

## atium

- Purpose: mostly-headless Mac server.
- Hardware: Apple Silicon or Intel -- arch detected via `uname -m`.
- Role: light CLI ops. Usually headless but occasionally attached to a
  display, so it keeps a minimal GUI surface. Nothing on this machine should
  require a graphical session.
- Special handling: remote access is plain SSH -- the 1Password SSH agent is
  off because a headless server cannot answer a TouchID prompt. Its own
  git/ssh identity keeps this machine's commits and authorized-key set
  attributable separately from personal and work.

## ci

- Purpose: the GitHub Actions runner profile.
- Hardware: whatever the runner image provides; arch detected at resolve
  time.
- Role: runs `task lint` and `task test` against the repo. It is a real
  machine manifest rather than a special case in the workflow, so CI
  exercises the same resolver path as a laptop.
- Special handling: no identity overlay, no GUI, no Claude surface. If a
  change makes CI need a package, that is a signal about the repo's own
  toolchain, not about CI.
