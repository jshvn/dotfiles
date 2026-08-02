# Machine Reference

## What This Is

This document captures per-machine prose that the TOML manifests cannot
express -- purpose, hardware narrative, role, and any special handling notes
the operator wants written down. For declarative state (feature flags,
identity selection, per-machine packages) the manifest TOML at
`manifests/machines/<name>.toml` is the source of truth. This doc is the
prose layer; it is brief by design and is updated when a machine's role
changes, not when a feature flag flips.

## personal-laptop

- Purpose: Josh's primary personal Mac, daily driver for personal projects
  and personal AI/CLI work.
- Hardware: Apple Silicon (`arm64`; declared explicitly in
  `[machine].arch`).
- Role narrative: full GUI + dev + personal feature set. Day-to-day use is
  personal-project development, dotfiles iteration, and Claude Code
  experimentation. The personal git/ssh identity is wired through this
  machine, and the personal cask set (Sourcetree, Sublime Text, Visual
  Studio Code, Raycast, Spotify, Discord, Slack, the Proton suite,
  Cloudflare WARP, Docker Desktop, and the Microsoft Office trio) all
  install here.
- Special handling: `jgrid-net` is on for the personal-network identity;
  `one-password-ssh` and `one-password-signing` are on so SSH and git
  commit signing flow through the 1Password agent; the
  `claude-marketplace` and `ghostty` features are on for the full
  development environment.
- See `manifests/machines/personal-laptop.toml` for declarative state
  (features, identity, packages).

## work-laptop

- Purpose: work-issued MacBook with the work git/ssh identity.
- Hardware: Apple Silicon or Intel -- arch detected by the resolver via
  `uname -m` because `[machine].arch` is absent in the work-laptop TOML.
- Role narrative: primary work development machine. Work identity is
  wired for git and SSH so commits and remote access carry the work
  attribution. Its declared package set is close to `personal-laptop`'s
  (Sublime Text, Visual Studio Code via the `vscode` flag, the Microsoft
  Office trio, Slack, Raycast, GitFox) minus the personal-only extras
  (Discord, the Proton suite, Cloudflare WARP, Dropbox, NVIDIA GeForce NOW)
  and the `node` formula.
- Special handling: the divergence from `personal-laptop` is the work
  git/ssh identity, not the shared dev and productivity casks (both machines
  declare Microsoft Office, Sublime Text, and the rest). work-laptop omits the
  personal-only cask extras (the Proton suite, Discord, Cloudflare WARP,
  Dropbox, NVIDIA GeForce NOW)
  and the `node` formula, and turns off `macos-spotlight` and `jgrid-net`
  (the personal-network identity is not applicable on a work machine).
  `claude-marketplace` and `ghostty` are on for the development environment.
- See `manifests/machines/work-laptop.toml` for declarative state
  (features, identity, packages).

## atium

- Purpose: Mac atium, mostly-headless Mac server.
- Hardware: Apple Silicon or Intel -- arch detected by the resolver via
  `uname -m` because `[machine].arch` is absent in the atium TOML.
- Role narrative: mostly-headless Mac server -- usually headless but
  occasionally connected to a display, so it still declares the 1Password
  application and enables `ghostty`. Declares the CLI utilities plus the casks
  `1password`, `appcleaner`, `cloudflare-warp`, `dropbox`, `miniconda`, and
  `orbstack`; no MAS apps. It disables `repo-dev-toolchain` (it does not lint
  this repo) and `vscode`. The atium git/ssh identity isolates this
  machine's commits and
  remote access from the personal and work identities so logs and
  authorized-key sets stay attributable. `claude-marketplace` is off
  because the machine has no interactive Claude Code surface; the GUI
  feature flags (`macos-dock`, `macos-finder`, `macos-input`,
  `macos-screenshots`) are in atium's `[features] disabled` list, so only the
  `macos-security` defaults concern runs as part of `task macos:apply-defaults`.
- Special handling: remote access flows through SSH; the
  `one-password-ssh` feature is off because a headless server cannot
  prompt for the 1Password TouchID approval. Intended workload is light
  CLI ops; nothing on this machine should require a graphical session.
- See `manifests/machines/atium.toml` for declarative state (features,
  identity, packages).
