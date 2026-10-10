# Security: Bootstrap Trust Chain

## What This Document Covers

The trust chain `bootstrap.zsh` establishes on a fresh machine: what is fetched, from where,
how (or whether) each artifact is verified, and which trust anchors the installer inherits
from. Scope is the three tools the script acquires (Homebrew, go-task, Nix) and the audit
signals it emits before doing so. SSH keys live in the identity layer; Claude hook
secret-scanning lives in the jshvn/ai repo.

The per-machine security boundary is explicit selection: every switch keys off the machine
name `task setup` wrote to `$XDG_STATE_HOME/dotfiles/machine`, never a hostname or an
environment variable.

---

## Bootstrap Trust Chain

### Step 1 -- Homebrew installer

- **What is downloaded:** the Homebrew install shell script (`install.sh`).
- **From where:** `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`.
- **How it is verified:** HTTPS only. No checksum pin. No signature verification.
- **Why this trust boundary is accepted:** the canonical install path published by `brew.sh`;
  a checksum pin would need updating on every installer change for little gain over HTTPS.
- **Audit signal:** before fetching, `bootstrap.zsh` prints an `AUDIT:` block to stderr
  naming the source URL and the trust note, then requires a single keypress read from
  `/dev/tty` (Enter to proceed; any other key aborts). Consent from the terminal means
  bootstrap cannot run through a `curl ... | zsh` pipe.

### Step 2 -- go-task

- **What is downloaded:** the Homebrew bottle for `go-task`.
- **From where:** `ghcr.io/homebrew/core/...`; formula metadata from `formulae.brew.sh`.
- **How it is verified:** Homebrew checks the bottle's SHA-256 against the formula before
  installing.
- **Why this trust boundary is accepted:** stronger than Step 1; tampering with the bottle at
  rest is caught by the checksum.

### Step 3 -- Nix, the official multi-user installer

- **What is downloaded:** the Nix install script, then the Nix release tarball it fetches.
- **From where:** `https://nixos.org/nix/install` (a redirect to `releases.nixos.org`); the
  tarball from `releases.nixos.org`, with the SHA-256 the script embeds.
- **How it is verified:** the script, HTTPS only, no checksum pin; the tarball, by the SHA-256
  inside the script.
- **What it does with sudo:** creates the `/nix` APFS volume (`/etc/synthetic.conf`,
  `/etc/fstab` through `vifs`), the `nixbld` group and build users, the `nix-daemon` launchd
  job and `/etc/nix/nix.conf`; prepends a block sourcing `nix-daemon.sh` to `/etc/zshrc` and
  `/etc/bashrc`, keeping `.backup-before-nix` copies.
- **Why this trust boundary is accepted:** it is the upstream installer, the same path
  jgrid.net's Macs use. `bootstrap.zsh` downloads it to a file first and prints the path, so
  it can be read before the consent keypress; the script then runs from that file, not from a
  pipe.
- **Audit signal:** the same `AUDIT:` block and keypress as Step 1.

### After bootstrap -- the switch

`darwin-rebuild switch` fetches the nixpkgs, nix-darwin and home-manager sources
`flake.lock` pins (by content hash) and any store paths from `cache.nixos.org`, each
signature-checked against the cache's key. Nix supplies nix-darwin, home-manager, the Nix
daemon nix-darwin runs in place of the installer's, and nixpkgs' CA bundle at
`/etc/ssl/certs/ca-certificates.crt`; every package Josh uses comes from Homebrew, with its
bottle checksums. `bootstrap.zsh` ends by running `task setup` and `task install`, whose switch
asks for sudo.

---

## Threat Model

| Threat | Mitigation | Residual Risk |
|--------|------------|---------------|
| MITM on `raw.githubusercontent.com` or `nixos.org` during an installer fetch | TLS only | Real -- accepted as the cost of an unpinned install path |
| Compromise of the GitHub mirror or `releases.nixos.org` serving an installer | HTTPS only; the Nix script is saved and can be read before it runs | Real -- documented |
| Compromise of a Homebrew bottle in the CDN | SHA-256 validated by `brew` | Mitigated |
| Compromise of formula metadata declaring a wrong SHA-256 | Formula commits are PR-reviewed by Homebrew | Mitigated |
| A tampered store path from `cache.nixos.org` | Nix verifies the narinfo signature | Mitigated |
| A flake input moved under the same name | `flake.lock` pins content hashes | Mitigated |
| Local user runs bootstrap with a hostile `$DOTFILEDIR` | `bootstrap.zsh` resolves it from `$0` | Mitigated |

---

## Trust Anchors

1. **Apple.** macOS itself, `curl`, `sh`, `zsh`, the system TLS trust store.
2. **GitHub Inc.** `raw.githubusercontent.com` and `ghcr.io`, and the flake inputs
   `flake.nix` declares and `flake.lock` pins (the nixpkgs, nix-darwin and home-manager
   sources).
3. **The Homebrew project.** The install script, formula metadata, the bottling pipeline.
4. **The NixOS Foundation.** `nixos.org`, `releases.nixos.org`, `cache.nixos.org` and its
   signing key, and the nixpkgs sources the lock pins.
5. **The nix-darwin and home-manager projects.** The module code the lock pins and the
   switch evaluates.

---

## What This Document Does NOT Cover

- **SSH key handling** -- `identity/`; the 1Password agent is wired by `apps/1password/`
  (`env.zsh` exports `SSH_AUTH_SOCK`, `agent.toml` orders the keys) and the `IdentityAgent`
  lines in `identity/ssh/identities/<name>`.
- **Claude hook secret-scanning** -- the jshvn/ai repo.
- **Per-machine credential management** -- no secret enters the repo; SSH and signing keys
  stay in 1Password.

---

## How to Audit

```bash
# What bootstrap will run (Step 1):
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | less

# What bootstrap will run (Step 3), or read the copy bootstrap.zsh saved:
curl -fsSL https://nixos.org/nix/install | less

# go-task's bottle SHA-256 (Step 2):
brew info --json=v2 go-task | jq '.formulae[0].bottle.stable.files'
```

---

## Future Hardening

Not in scope:

- **Pinned-checksum installers.** Vendor both install scripts at a known commit and verify
  their checksums before execution. Eliminates the residual Step 1 and Step 3 risk at the cost
  of installer staleness.

Structural regressions are gated: `.github/workflows/ci.yml` evaluates every machine and
profile, lints, runs the hermetic tests and builds lerasium's closure on every push to `master`
and every pull request.
