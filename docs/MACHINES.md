# Machine Reference

## What This Is

This document captures per-machine prose that the TOML manifests cannot
express -- purpose, hardware narrative, role, and any special handling notes
the operator wants written down. For declarative state (feature flags,
identity selection, package bundles, extra packages) the manifest TOML at
`manifests/machines/<name>.toml` is the source of truth. This doc is the
prose layer; it is brief by design and is updated when a machine's role
changes, not when a feature flag flips.

## personal-laptop

- Purpose: Josh's primary personal Mac, daily driver for personal projects
  and personal AI/CLI work.
- Hardware: Apple Silicon (`arm64`; declared explicitly in
  `[platform].arch`).
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
  (features, identity, package bundles).

## work-laptop

- Purpose: work-issued MacBook with the work git/ssh identity.
- Hardware: Apple Silicon or Intel -- arch detected by the resolver via
  `uname -m` because `[platform].arch` is absent in the work-laptop TOML.
- Role narrative: primary work development machine. Work identity is
  wired for git and SSH so commits and remote access carry the work
  attribution; the cask set is the work-flavored subset of the GUI bundle
  (Sourcetree, Sublime Text, Visual Studio Code, the Microsoft Office
  trio, Slack, Zoom, Firefox, Raycast, miniconda, Docker Desktop). No
  personal apps (Discord, WhatsApp, the Proton suite, Cloudflare WARP)
  install here.
- Special handling: work-specific tooling (Sourcetree, Microsoft Office)
  is the divergence point from `personal-laptop`; `claude-marketplace`
  and `ghostty` are on for the development environment. The
  `jgrid-net` feature is off because the personal-network identity is
  not applicable on a work machine.
- See `manifests/machines/work-laptop.toml` for declarative state
  (features, identity, package bundles).

## atium

- Purpose: Mac atium, headless ops machine, core packages only.
- Hardware: Apple Silicon or Intel -- arch detected by the resolver via
  `uname -m` because `[platform].arch` is absent in the atium TOML.
- Role narrative: headless operations machine. Runs only the `core`
  Brewfile bundle (CLI tooling); no GUI bundle, no extra casks, no MAS
  apps. The atium git/ssh identity isolates this machine's commits and
  remote access from the personal and work identities so logs and
  authorized-key sets stay attributable. `claude-marketplace` is off
  because the machine has no interactive Claude Code surface; the GUI
  feature flags (`macos-dock`, `macos-finder`, `macos-input`,
  `macos-screenshots`) are absent and inherit `false`, so only the
  `macos-security` defaults concern runs as part of `task macos:defaults`.
- Special handling: remote access flows through SSH; the
  `one-password-ssh` feature is off because a headless server cannot
  prompt for the 1Password TouchID approval. Intended workload is light
  CLI ops; nothing on this machine should require a graphical session.
- See `manifests/machines/atium.toml` for declarative state (features,
  identity, package bundles).

## server-2

- Purpose: Mac server-2, headless ops machine, core packages only.
- Hardware: Apple Silicon or Intel -- arch detected by the resolver via
  `uname -m` because `[platform].arch` is absent in the server-2 TOML.
- Role narrative: second headless operations machine, structurally
  mirroring `atium`. Runs only the `core` Brewfile bundle; no GUI
  bundle, no extra casks, no MAS apps. The server-2 git/ssh identity is
  distinct from atium so the two machines remain individually
  attributable in commit logs, authorized-key sets, and audit trails
  even when their workload is interchangeable. `claude-marketplace` and
  the GUI feature flags are all off; `macos-security` is the only macOS
  defaults concern that runs.
- Special handling: same shape as `atium` -- SSH-only access,
  `one-password-ssh` off, headless workload. Operating two server
  machines with separate identities is intentional: it keeps the
  blast-radius of a compromised key bounded to a single host.
- See `manifests/machines/server-2.toml` for declarative state (features,
  identity, package bundles).
