# Security: Bootstrap Trust Chain

## What This Document Covers

This document describes the trust chain established by `bootstrap.zsh`
when a fresh machine first runs the dotfiles installer. It enumerates
what software is fetched, where it is fetched from, how (or whether)
each artifact is verified, and which trust anchors the installer
inherits from.

Scope is intentionally narrow: only the three tools the bootstrap
script acquires (Homebrew, go-task, yq) and the audit signals the
script emits before doing so. SSH key handling is deferred to Phase 4
(identity layer); Claude hook secret-scanning is deferred to Phase 7
hardening; per-machine credential management is documented in
`docs/MACHINES.md` (Phase 8).

The repository's per-machine security boundary is the manifest model
itself: every install action keys off the machine name written to
`$XDG_STATE_HOME/dotfiles/machine` by `task setup`, so an install never
proceeds on the basis of hostname inference or environment-variable
sniffing.

---

## Bootstrap Trust Chain

### Step 1 -- Homebrew installer

- **What is downloaded:** the Homebrew install shell script (`install.sh`).
- **From where:** `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`.
- **How it is verified:** HTTPS only. No checksum pin. No signature verification.
- **Why this trust boundary is accepted:** this is the canonical install path
  published by `brew.sh`. Pinning to a checksum would require updating the pin
  every time Homebrew ships an installer change; the maintenance burden
  outweighs the security delta over HTTPS-only retrieval. We accept the same
  trust boundary as the wider macOS development community.
- **Audit signal:** before fetching the installer, `bootstrap.zsh` prints an
  `AUDIT:` line to stderr identifying the source URL and the trust note, and
  sleeps for 3 seconds so an attentive user has an explicit abort window
  (Ctrl-C). The audit line wording is:
  ```
  AUDIT: about to fetch and execute brew install script
    source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    trust:  HTTPS only, no checksum pin (see docs/SECURITY.md)
  ```

### Step 2 -- go-task and yq

- **What is downloaded:** Homebrew formula bottles for `go-task` and `yq`.
- **From where:** Homebrew's CDN. Bottle artifacts come from
  `ghcr.io/homebrew/core/...`; formula metadata is served from
  `formulae.brew.sh`.
- **How it is verified:** Homebrew computes SHA-256 checksums for every
  bottle and refuses to install if the downloaded artifact does not match
  the formula's declared checksum.
- **Why this trust boundary is accepted:** stronger than Step 1. We inherit
  Homebrew's standard formula-verification path: any tampering with the
  bottle artifact at rest in the CDN is caught by checksum mismatch before
  installation proceeds.

---

## Threat Model

| Threat | Mitigation | Residual Risk |
|--------|------------|---------------|
| MITM on `raw.githubusercontent.com` during installer fetch | TLS only | Real -- accepted as the pragmatic cost of a non-pinned install path |
| Compromise of GitHub mirror serving the installer | HTTPS only; no signature check | Real -- documented; mitigated only by GitHub's own infrastructure integrity |
| Compromise of a Homebrew bottle artifact in the CDN | SHA-256 checksum validated by `brew` before install | Mitigated |
| Compromise of formula metadata declaring a wrong SHA-256 | Formula commits are PR-reviewed by Homebrew | Mitigated -- accept Homebrew's review process as the gate |
| Local user runs bootstrap with hostile `$DOTFILEDIR` env override | `bootstrap.zsh` re-resolves `DOTFILEDIR` from `$0` at script start, ignoring inherited env | Mitigated |

---

## Trust Anchors

The bootstrap trust chain inherits from three named anchors:

1. **Apple.** macOS itself, including system `curl`, `bash`, `zsh`, and the
   system TLS trust store. If macOS is compromised, the entire installer is
   compromised.
2. **GitHub Inc.** `raw.githubusercontent.com` (TLS termination, repository
   integrity for the Homebrew install script) and `ghcr.io` (artifact storage
   for Homebrew bottles).
3. **The Homebrew project.** The correctness of the install script, the
   integrity of formula metadata, and the bottling pipeline that produces
   the artifacts in `ghcr.io`.

---

## What This Document Does NOT Cover

- **SSH key handling** -- deferred to Phase 4 (identity layer). Phase 4 will
  document how SSH keys are generated, stored (1Password agent integration),
  and rotated.
- **1Password agent integration** -- deferred to Phase 4. The non-server
  machines route SSH agent traffic through 1Password; the trust model for
  that integration belongs in Phase 4's doc.
- **Claude hook secret-scanning** -- deferred to Phase 7 hardening. The
  hook that blocks commits containing secrets is documented in Phase 7.
- **Per-machine credential management** -- out of scope for v1. Anything
  beyond the universal bootstrap path is documented in `docs/MACHINES.md`
  (Phase 8).

---

## How to Audit

Two concrete commands let you inspect what bootstrap will run before you
let it run:

```bash
# Inspect what bootstrap will run (Step 1):
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | less

# Verify go-task's bottle SHA-256 (Step 2):
brew info --json=v2 go-task | jq '.formulae[0].bottle.stable.files'
```

The first command pages through the actual installer source code Homebrew
will execute. The second prints the per-platform bottle URLs and SHA-256
checksums that `brew install go-task` will verify before completing.

---

## Future Hardening

Listed for reference; not in v1 scope:

- **Pinned-checksum brew installer.** Vendor `install.sh` at a known git
  commit and verify its checksum before execution. Eliminates the residual
  Step 1 risk at the cost of installer staleness.
- **Shellcheck integration for hooks.** Lint the Claude hook scripts and
  any zsh script that handles secrets, surfacing common injection
  anti-patterns at commit time.
- **GitHub Actions CI for lint regression detection.** Run the Phase 2 lint
  suite (`task lint`) on every PR to catch structural violations before
  they land on the default branch.
