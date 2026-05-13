# Testing Patterns

**Analysis Date:** 2026-05-13

## Overview

This is a dotfiles repository. There is no unit test framework. Correctness is verified through `task validate`, which runs a battery of sanity checks against the live system state. These checks confirm that symlinks are in place, required commands are available, profiles are configured, and system settings have been applied.

## Validation Framework

**Runner:** go-task (`Taskfile.yml`)
**Config:** `Taskfile.yml` (root), `taskfiles/*.yml` (per-component)

**Run Commands:**
```bash
task validate              # Full validation (all components for current profile)
task links:validate        # Symlinks only
task common:validate       # XDG dirs, ZDOTDIR, Antigen
task brew:validate         # Homebrew install
task claude:validate       # Claude CLI, plugins, marketplaces
task macos:validate        # Shell, 1Password agent
task profile:validate      # Profile file existence and validity
task personal:validate     # Personal-profile-specific symlinks
task work:validate         # Work-profile-specific symlinks
task server:validate       # Server-profile-specific symlinks
```

## Validation Structure

Each taskfile owns its own `validate` task. The root `task validate` orchestrates them:

```yaml
# Taskfile.yml
validate:
  cmds:
    - task: common:validate
    - task: profile:validate
    - task: links:validate
    - task: brew:validate
    - task: claude:validate
    - task: macos:validate
    - task: "{{.PROFILE}}:validate"   # profile-specific
```

All validation output uses `check` (pass) and `cross` (fail) from `install/messages.zsh`:
- `check "description"` prints `✓ description` in green
- `cross "description"` prints `✗ description` in red

Validation tasks never exit non-zero on a failing check — they print the failure and continue. This gives a full picture of what is broken rather than stopping at the first issue.

## Validation Helpers

Four reusable helpers in `taskfiles/helpers.yml` cover all check types:

```yaml
# Check that a symlink exists and is not broken
- task: _:check-link
  vars: { TARGET: "{{.ZDOTDIR}}/.zshrc", NAME: "zshrc" }

# Check that a directory exists
- task: _:check-dir
  vars: { TARGET: "{{.XDG_CONFIG_HOME}}", NAME: "XDG config home" }

# Check that a file exists
- task: _:check-file
  vars: { TARGET: "{{.HOMEBREW_PREFIX}}/share/antigen/antigen.zsh", NAME: "Antigen" }

# Check that a command is in PATH
- task: _:check-command
  vars: { CMD: "brew", NAME: "Homebrew" }
```

All helpers source `$DOTFILES_MESSAGES` for consistent output formatting.

## What Gets Validated

### Symlinks (`taskfiles/links.yml` → `links:validate`)
Every symlink created by `links:all` is verified: all zsh dot-files, git config, SSH config, tool configs (trippy, tlrc, eza, conda, ghostty, glow), and all Claude Code config symlinks. Also checks that all `.zsh` hook scripts under `claude/hooks/` are executable (skips `lib.zsh` since it is sourced, not executed directly).

### XDG Directories (`taskfiles/common.yml` → `common:validate`)
Checks that all four XDG base directories exist and that ZDOTDIR is configured in `/etc/zshenv`.

### Homebrew (`taskfiles/brew.yml` → `brew:validate`)
Checks that `brew` is in PATH.

### Claude Code (`taskfiles/claude.yml` → `claude:validate`)
Checks that the `claude` CLI and `jq` are installed, that each configured marketplace is registered, and that each configured plugin is installed.

### macOS System State (`taskfiles/macos.yml` → `macos:validate`)
Checks that Homebrew zsh is in `/etc/shells`, that the default shell is Homebrew zsh, and (for non-server profiles) that the 1Password SSH agent socket is active.

### Profile (`taskfiles/profile.yml` → `profile:validate`)
Checks that the profile file exists at `$XDG_CONFIG_HOME/dotfiles/profile` and contains a valid value (`personal`, `work`, or `server`).

### Profile-Specific (`taskfiles/profile-tasks.yml` → `<profile>:validate`)
Checks profile-specific git config symlink (`config-<profile>`) and SSH config symlink (`config-<profile>`). Also checks SSH public key symlink if the source key file exists.

## Installation Idempotency Checks

Each install task has a `status:` block, making installs double as lightweight checks. If all `status:` conditions pass, go-task skips the task entirely (no install needed). This pattern is used across all install tasks in all taskfiles.

```yaml
zsh:
  cmds:
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
  status:
    - test -L "{{.ZDOTDIR}}/.zshenv"
```

## Hook Script Behavior (Runtime Correctness)

Claude Code hooks in `claude/hooks/` act as runtime guards enforcing code quality rules. They are not unit tests but serve a test-like function for code written by Claude:

| Hook | Type | What It Checks |
|------|------|----------------|
| `block-destructive.zsh` | Pre-tool, blocking | Destructive `git` and `rm -rf` commands |
| `secret-scan.zsh` | Pre-tool, blocking | AWS keys, GitHub tokens, private key headers, credential patterns in writes |
| `no-emojis.zsh` | Post-tool, advisory | Emoji Unicode ranges in non-markdown files |
| `no-ai-comments.zsh` | Post-tool, advisory | AI attribution patterns in any written content |
| `agent-transparency.zsh` | Pre-tool, informational | Logs subagent delegation for conversation transparency |
| `notify.zsh` | Event, informational | macOS desktop notification on task completion |
| `post-compact.zsh` | Session, informational | Re-injects git state after context compaction |

Blocking hooks (`block-destructive.zsh`, `secret-scan.zsh`) use `hook::require_ggrep block` which exits 2 (blocking the tool call) if `ggrep` is not found — they fail closed.

Advisory hooks (`no-emojis.zsh`, `no-ai-comments.zsh`) use `hook::require_ggrep warn` which exits 0 (non-blocking) if `ggrep` is not found — they fail open.

## Test Coverage Gaps

**No automated shell script testing:**
- zsh functions in `zsh/functions/` have no unit tests
- alias files are not linted or tested
- No shellcheck CI run (no `.shellcheckrc`, no CI pipeline configured)
- No `bats` or similar shell test framework

**Validation is state-dependent:**
- `task validate` only works correctly after `task install` on a real machine
- Cannot be run in CI without a full macOS environment with Homebrew installed
- No mock/dry-run mode for validation

**What is not checked by validate:**
- That zsh dot-files parse without error (`zsh -n <file>` syntax check)
- That function files load without error when sourced
- That aliases resolve to valid commands (only symlink presence is checked)
- That macOS `defaults` are set to correct values (checked by `status:` but not by `validate`)
- That SSH configs are syntactically valid (`ssh -G` check)
- That profile-specific Brewfiles are syntactically valid

**Priority gaps:**
- High: No syntax checking of zsh files — a typo in `.zshrc` silently breaks the shell
- Medium: No validation that Homebrew-resolved tools in aliases actually exist
- Low: No check that tool config files (trippy, glow, etc.) are parseable by their respective tools

---

*Testing analysis: 2026-05-13*
