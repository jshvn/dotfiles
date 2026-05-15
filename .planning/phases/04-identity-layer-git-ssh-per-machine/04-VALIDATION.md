---
phase: 4
slug: identity-layer-git-ssh-per-machine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-14
---

# Phase 4 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from `04-RESEARCH.md` -> Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task subtasks + zsh assertion scripts (consistent with Phase 1-3) |
| **Config files** | `taskfiles/identity.yml` (new), `install/resolver.zsh` (extended) |
| **Quick run command** | `task lint && task manifest:test` |
| **Full suite command** | `task manifest:test && task lint && task identity:validate` |
| **Phase gate command** | `task identity:validate` (must exit 0 with all four assertions green) |
| **Estimated runtime** | ~5 seconds (lint + manifest:test); ~2 seconds for `identity:validate` |

---

## Sampling Rate

- **After every task commit:** Run `task lint && task manifest:test` (covers schema + lint passes; ~2-3 seconds total).
- **After every plan wave:** Run `task identity:validate` on a machine that has run `task setup -- <machine>` and `task install` (covers symlink integrity + git/ssh assertions).
- **Before `/gsd-verify-work`:** `task identity:validate` green; `task manifest:test` green; `task lint` green.
- **Max feedback latency:** 5 seconds for the quick run; 7-10 seconds for the full suite.

---

## Per-Task Verification Map

> Filled in by the planner as PLAN.md files are written. Each task listed in a PLAN.md gets one row here. The table below seeds the requirement-level rows from `04-RESEARCH.md` so the planner can attach `Task ID` and `Plan` once plans are produced.

| Req | Behavior | Test Type | Automated Command | Wave 0 Dep |
|-----|----------|-----------|-------------------|------------|
| IDNT-01 | Main git config uses `includeIf gitdir:` for path-based identity selection | unit (file content) | `grep -q 'gitdir/i:~/git/personal/' identity/git/config` | yes |
| IDNT-02 | Per-identity git configs live under `identity/git/identities/<name>` with no profile-suffix filenames | unit (directory listing) | `find identity/git/identities -type f -name 'config-*' \| wc -l` -> 0 | yes |
| IDNT-03 | Main SSH config uses `Include` for identity selection | unit (file content) | `grep -q 'Include ~/.ssh/identities/active' identity/ssh/config` | yes |
| IDNT-04 | Per-identity SSH configs live under `identity/ssh/identities/<name>` with no profile-suffix filenames | unit (directory listing) | `find identity/ssh/identities -type f -name 'config-*' \| wc -l` -> 0 | yes |
| IDNT-05 | 1Password SSH agent integration gated by `features.one-password-ssh`; no hostname literals in identity path | integration (cross-field + audit) | (a) `task manifest:validate` accepts personal + opssh=true; rejects personal + opssh=false. (b) `grep -rEn 'hostname\|scutil' identity/ taskfiles/identity.yml` returns 0 lines | yes |
| IDNT-06 | Public SSH keys committed under `identity/ssh/keys/`; private keys never committed | unit (directory contents) | `find identity/ssh/keys -maxdepth 1 -type f -not -name '*.pub' -not -name '.gitignore'` -> empty | yes |
| IDNT-07 | `task validate` (composed in Phase 8) asserts git config user.email and ssh-add -L | integration | `task identity:validate` performs git config + ssh-add -L checks (latter skipped when `one-password-ssh = false`) | yes |
| IDNT-08 | `taskfiles/identity.yml` reads identity from `resolved.json` and creates symlinks via `_:safe-link` | integration (file + structural) | (a) `grep -q 'ref: .fromJson .MANIFEST_JSON' taskfiles/identity.yml`. (b) `task lint:taskfile` passes (no bare `ln -s` outside helpers.yml; status blocks use `{{.X}}` only) | yes |

*Status legend (planner fills in per-task rows): pending / green / red / flaky.*

---

## Wave 0 Requirements

- [ ] `taskfiles/identity.yml` - new file housing `install`, `git`, `ssh`, `validate` subtasks
- [ ] `install/resolver.zsh` - extended `validate_manifest()` with cross-field rules + expanded enum case-statement
- [ ] `manifests/test/fixtures/_invalid-identity-without-opssh/` - negative fixture (`identity.ssh = "personal"` with `one-password-ssh = false`)
- [ ] `manifests/test/fixtures/_invalid-identity-without-opsign/` - negative fixture (`identity.git = "personal"` with `one-password-signing = false`)
- [ ] `manifests/test/fixtures/_invalid-bad-identity/` - negative fixture (`identity.ssh = "alice"` to verify enum rejection)
- [ ] `taskfiles/manifest.yml` `manifest:test` - extend with the three new negative fixtures (matches existing `_invalid-missing-desc` / `_invalid-bad-os` pattern)
- [ ] `identity/ssh/keys/.gitignore` - allowlist `*.pub` (belt-and-braces for IDNT-06)
- [ ] `identity/README.md` - replace P1 stub with Phase 4 content
- [ ] `docs/MANIFEST.md` - schema reference updates: identity enum + `one-password-signing` row

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `git -C ~/git/personal/<repo> config user.email` returns the personal email; `git -C ~/git/work/<repo> config user.email` returns the work email | IDNT-01 | Requires real repos at the expected paths; cannot be asserted on the dotfiles repo itself without polluting it with fixture clones | After Phase 4 install, run `git -C ~/git/personal/dotfiles config user.email` and `git -C ~/git/work/<any work repo> config user.email` and confirm distinct values |
| `ssh -G github.com` on a `one-password-ssh = true` machine resolves `IdentityAgent` to the 1Password socket | IDNT-05 | Requires 1Password.app installed and the SSH agent enabled in 1Password preferences | After `task install`, run `ssh -G github.com \| grep -i 'identityagent\\|user'` and confirm `identityagent ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` |
| 1Password SSH agent surface (socket actually serves keys) | IDNT-05 | Requires GUI consent flow; cannot be scripted | Run `SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ssh-add -L`; confirm output lists the personal key |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or a Wave 0 dependency listed above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (the planner enforces this)
- [ ] Wave 0 covers all MISSING references in the per-task table
- [ ] No watch-mode flags in any test command
- [ ] Feedback latency < 10 seconds for the full suite
- [ ] `nyquist_compliant: true` set in frontmatter once the planner attaches Task IDs and the executor lands Wave 0

**Approval:** pending
