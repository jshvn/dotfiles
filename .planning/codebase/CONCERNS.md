# Codebase Concerns

**Analysis Date:** 2026-05-13

---

## Tech Debt

**`test` profile is declared but has no install artifacts:**
- Issue: `VALID_PROFILES` in `Taskfile.yml:21` lists `"personal server work test"`, and `Taskfile.yml:61-72` includes `personal`, `work`, and `server` profile-task namespaces, but there is no `test` namespace included. Running `task test:install` or `task test:validate` will fail with a task-not-found error. There is also no `Brewfile-test.rb`, no `git/config-test`, and no `ssh/configs/config-test`.
- Files: `Taskfile.yml:21`, `Taskfile.yml:61-72`
- Impact: Any CI/dry-run workflow that selects the `test` profile will error at install time. The profile:ensure prompt will accept "test" as valid, then the install step will crash.
- Fix approach: Either remove `test` from `VALID_PROFILES`, add a corresponding namespace include and stub artifacts, or document that `test` is reserved and add a precondition guard.

**`macos:shell` status check uses unexpanded shell variable:**
- Issue: `taskfiles/macos.yml:145` uses `$BREW_ZSH` (shell variable) instead of `{{.BREW_ZSH}}` (task template variable). Task evaluates `status:` checks in a fresh shell where `$BREW_ZSH` is unset, so the status check always returns false, causing the task to re-run on every `task install`.
- Files: `taskfiles/macos.yml:145`
- Impact: Idempotency broken — `macos:shell` runs on every install, triggering `chsh` prompts and `/etc/shells` writes unnecessarily.
- Fix approach: Change line 145 to `- grep -qxF "{{.BREW_ZSH}}" /etc/shells`.

**`pubkey` function references a stale key name in its docstring:**
- Issue: `zsh/functions/pubkey.zsh:4` documents the example as `pubkey id_rsa_adobe.pub`, referencing a previous employer and a deprecated RSA key format. The actual key available is `id_ed25519_personal.pub`.
- Files: `zsh/functions/pubkey.zsh:4`
- Impact: Low — misleading example, but the function itself works generically.
- Fix approach: Update the inline docstring example to `pubkey id_ed25519_personal.pub`.

**`brew:bundle` and `brew:update` lack `status:` checks:**
- Issue: `taskfiles/brew.yml` — the `bundle` and `update` tasks have no `status:` guards. They rely on `run: once` only for `update` within a single task run, but `bundle` has no protection at all. Running `task install` twice in the same session re-runs `brew bundle` which is slow (30–90 seconds).
- Files: `taskfiles/brew.yml:52-63`
- Impact: Slow re-installs. No correctness risk since `brew bundle` is idempotent, but wastes time.
- Fix approach: Add a `status:` check using a sentinel file (e.g. `test -f {{.XDG_CACHE_HOME}}/dotfiles/.brew-bundled`) or accept the current behavior as intentional for freshness.

**`gsd-install` task always re-runs `npx` on every `task install`:**
- Issue: `taskfiles/claude.yml:211-219` — the `gsd-install` task has no `status:` check and no `run: once` guard. Every `task install` invocation runs `npx -y get-shit-done-cc@latest --claude --global`, which fetches from the network, even when GSD is already current.
- Files: `taskfiles/claude.yml:211-219`
- Impact: Slow installs, unnecessary network dependency on every re-install.
- Fix approach: Add `run: once` to `gsd-install`, or add a `status:` check that tests whether the GSD commands exist in the Claude commands directory.

---

## Known Bugs

**`bootstrap.zsh` uses `set -e` instead of `set -euo pipefail`:**
- Symptoms: Unset variable references and pipe failures in bootstrap are silently ignored. For example, if `DOTFILEDIR` somehow resolves empty, subsequent `task install` would run from the wrong directory without error.
- Files: `bootstrap.zsh:2`
- Trigger: Any unbound variable or pipe failure in bootstrap script body.
- Workaround: None — the script completes with potentially wrong state.
- Fix approach: Change `set -e` to `set -euo pipefail` on line 2.

**`bootstrap.zsh` pipes `curl` output directly to `sh` with no integrity check:**
- Symptoms: The go-task installer script is fetched and executed without checksum verification: `sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b "$INSTALL_DIR"`. A MITM or CDN compromise would silently execute arbitrary code.
- Files: `bootstrap.zsh:33`
- Trigger: Bootstrap on a fresh machine with no prior go-task install.
- Workaround: Pre-install go-task via another trusted mechanism before running bootstrap.
- Fix approach: Download the install script, verify its checksum against the published hash, then execute. Or install go-task via Homebrew from within bootstrap before any other step.

**`.zprofile` detects server profile by hostname literal, not by `$DOTFILES_PROFILE`:**
- Symptoms: `zsh/.zprofile:55` checks `if [[ "$(hostname -s)" != "server" ]]` to decide whether to set the 1Password SSH auth socket. This means any machine whose hostname happens to contain "server" (e.g., "fileserver", "webserver-local") will skip 1Password. Conversely, a server machine with a non-"server" hostname will get the 1Password socket path set, which does not exist, breaking SSH.
- Files: `zsh/.zprofile:55-56`
- Trigger: Hostname-based detection instead of profile-based detection.
- Workaround: Manually rename machine to "server" exactly.
- Fix approach: Replace hostname check with `[[ "$DOTFILES_PROFILE" != "server" ]]`, which is already available at `.zprofile` source time since `.zshenv` sets it at line 73.

**`agent-transparency.zsh` uses `local` at script scope (outside a function):**
- Symptoms: `claude/hooks/agent-transparency.zsh:11,39` declares `local agent_type description cwd agent_md` and `local output` at top-level script scope. In zsh scripts (non-function context), `local` is technically allowed but marks variables as local to the current scope level, which is the entire script — effectively equivalent to no scoping. This is a correctness hazard if zsh version behavior changes, and shellcheck flags it as an error.
- Files: `claude/hooks/agent-transparency.zsh:11`, `claude/hooks/agent-transparency.zsh:39`
- Trigger: Any shellcheck run or strict zsh interpreter.
- Fix approach: Move the hook body into a main function and call it, or simply use unscoped variable declarations.

---

## Security Considerations

**`bootstrap.zsh` curl-to-shell pipe:**
- Risk: Supply chain attack via compromised CDN or MITM. The taskfile.dev install script is fetched over HTTPS but not checksum-verified before execution.
- Files: `bootstrap.zsh:33`
- Current mitigation: HTTPS only — no checksum validation.
- Recommendations: Use Homebrew to install go-task (`brew install go-task`) as the primary path, or verify checksum before execution.

**`ssh/configs/agent.toml` is tracked in the repo:**
- Risk: `ssh/configs/agent.toml` is committed and linked to `~/.config/1Password/ssh/agent.toml`. The file contains the 1Password SSH agent socket configuration. While it contains no secrets itself, exposing the exact socket path and configuration publicly documents the local security setup.
- Files: `ssh/configs/agent.toml`
- Current mitigation: File appears to contain only configuration, no tokens.
- Recommendations: Acceptable as-is; monitor if 1Password adds any authentication tokens to this file format in future releases.

**`ssh/configs/config` uses `cat` with an exec match to detect profile, exposed to injection:**
- Risk: `ssh/configs/config:13-20` uses `Match exec "test \"$(cat ...)\" = 'personal'"`. The profile file value is read via shell substitution inside the SSH config's `Match exec` stanza. If the profile file is ever written with unexpected content (newlines, shell metacharacters), it could cause misbehavior in SSH config parsing.
- Files: `ssh/configs/config:13-20`
- Current mitigation: Profile file is written only by `task profile:set` which validates against `VALID_PROFILES` before writing.
- Recommendations: The validation in `profile.yml` is sufficient protection; no change needed unless the profile file gains a broader write surface.

**`zsh/functions/cheat.zsh` fetches from `cheat.sh` without TLS verification flag:**
- Risk: `curl "cheat.sh"` uses HTTP (not HTTPS), sending the query in plaintext and allowing MITM to return malicious command syntax presented as helpful cheat sheet output.
- Files: `zsh/functions/cheat.zsh:7,12`
- Current mitigation: None — plain HTTP.
- Recommendations: Change to `curl "https://cheat.sh/${1}?style=xcode" -s` (the URL naturally redirects but curl should be told explicitly).

---

## Performance Bottlenecks

**`zsh/.zshrc` calls `antigen apply` on every interactive shell start:**
- Problem: `antigen apply` and `antigen use ohmyzsh/ohmyzsh` run on every new interactive shell, even when plugins are already loaded and cached. This adds 200–500ms to shell startup time.
- Files: `zsh/.zshrc:53-72`
- Cause: Antigen checks for updates and cache validity on each source.
- Improvement path: Add `ANTIGEN_AUTO_UPDATE=false` or consider migrating to `zinit` with turbo loading for faster startup. Alternatively, use antigen's `--no-lock` and cache aggressively.

**MOTD runs `git log`, `git status`, and `fastfetch` synchronously on login:**
- Problem: `zsh/functions/motd.zsh:67-72` runs git commands and `fastfetch` synchronously during every login shell. On slow disks or network mounts, this adds seconds to login time.
- Files: `zsh/functions/motd.zsh:51-83`
- Cause: No async execution, no TTL cache.
- Improvement path: Run MOTD components in a subshell with a timeout, or cache the output to a file with a TTL check.

---

## Fragile Areas

**`zsh/.zshrc` DOTFILEDIR resolution depends on symlink traversal at shell startup:**
- Files: `zsh/.zshrc:75-83`
- Why fragile: The symlink-traversal loop (`SOURCE="${(%):-%N}"` + `readlink`) runs on every interactive shell start. If `ZDOTDIR` is not a symlink (e.g., after a failed `task links:zsh`), `DOTFILEDIR` resolves to the `zsh/` subdirectory of `ZDOTDIR` instead of the repo root. All subsequent alias/function loading silently fails.
- Safe modification: Always verify `DOTFILEDIR` resolves correctly before modifying the sylink resolution logic. Test with `zsh -i -c 'echo $DOTFILEDIR'` after any change.
- Test coverage: No automated validation that `$DOTFILEDIR` is correct.

**`task links:ssh` creates the 1Password config dir with `mkdir -p` inside an inline shell block, not via `_:safe-link`:**
- Files: `taskfiles/links.yml:66-70`
- Why fragile: The 1Password agent.toml link is created with raw `ln -sf` rather than through the `_:safe-link` helper. If the `status:` check passes but the link is broken (pointing to wrong target), re-running will not fix it because `ln -sf` is behind the profile guard in an inline block with no force-refresh path.
- Safe modification: Refactor to use `_:safe-link` helper consistent with other link tasks.

**`common:zdotdir` writes to `/etc/zshenv` with `sudo tee`, which is destructive if `/etc/zshenv` has existing content:**
- Files: `taskfiles/common.yml:40-57`
- Why fragile: If `/etc/zshenv` already has other content (set by macOS updates or other tools), the task appends the ZDOTDIR export with `tee -a`. It checks for the exact string first, so it won't duplicate. However, if `/etc/zshenv` is managed by another tool after dotfiles install, re-running `task install` will not detect conflicts.
- Safe modification: The current guard (`grep -qF`) is adequate for normal use. The fragility is that `/etc/zshenv` content from macOS system updates is not preserved or validated beyond the ZDOTDIR line.

**`zsh/.zprofile` will crash with an unbound variable error if Homebrew is not installed:**
- Files: `zsh/.zprofile:36-47`
- Why fragile: `DIRECTORY` is set to a hardcoded brew path, then `eval "$($DIRECTORY shellenv)"` runs unconditionally. If brew is not installed at `$DIRECTORY`, this produces a "No such file or directory" error on every login shell, preventing `.zshrc` from loading normally. The error also leaks into non-interactive contexts.
- Safe modification: Wrap the `eval` in `[[ -x "$DIRECTORY" ]] && eval ...` to make it conditional, matching the approach used in `Taskfile.yml:43-45`.

---

## Scaling Limits

**`claude/skills/` directory contains 70+ skills as individual subdirectories:**
- Current capacity: 70+ skill directories, each with `SKILL.md` and `rules/` subdirectory.
- Limit: No technical limit, but task execution paths that iterate `skills/` (validation, update) will slow linearly with skill count. Claude context window cost also grows.
- Scaling path: Skills are externally sourced (via `ecc` marketplace). The current structure is inherently flat; no action needed until skill count exceeds ~200.

---

## Dependencies at Risk

**`highlight` (source highlighter) has no fallback in aliases or functions:**
- Risk: `highlight` is used in 14+ locations across aliases and functions (`zsh/aliases/common/general.zsh`, `zsh/functions/aliaslist.zsh`, etc.) with no `command -v highlight || cat` fallback. If `highlight` is not installed (e.g., on a server profile or mid-install), every affected alias produces an error instead of degraded output.
- Impact: `ls`, `history`, `path`, `aliaslist`, `functionlist`, `prettyjson`, `permissions`, `pubkey`, `host`, `ghpubkey`, `geoip`, `fs`, `sshlist` all fail visually. The commands still produce their output but exit with a pipe error code.
- Migration plan: Wrap `highlight` calls with `highlight ... 2>/dev/null || cat` fallback, or define a thin wrapper alias that checks availability.

**`fastfetch` is required for MOTD and `info` function but is not validated at use time:**
- Risk: `zsh/functions/motd.zsh:54-57` and `zsh/functions/info.zsh:14,16` call `fastfetch` without checking installation. The motd function has a graceful `2>/dev/null` fallback, but `info` does not.
- Impact: `info` function will error on machines where `fastfetch` is not installed (e.g., fresh install before `task brew:install`).
- Migration plan: Add `command -v fastfetch >/dev/null || { echo "fastfetch not installed"; return 1; }` guard to `info.zsh`.

**`shuf` (GNU coreutils) used in MOTD with a sort -R fallback:**
- Risk: `zsh/functions/motd.zsh:79` uses `shuf -n 1 "$quotes_file" 2>/dev/null || sort -R "$quotes_file" | head -1`. Both `shuf` and `sort -R` are GNU-specific; macOS system `sort` does not support `-R`. The fallback is also a GNU coreutils command that requires Homebrew's `coreutils` package.
- Impact: On a fresh machine before `brew install coreutils`, random quote selection silently produces empty output.
- Migration plan: Use `awk 'BEGIN{srand()} {print rand(), $0}' | sort | head -1 | cut -d' ' -f2-` as a portable fallback, or add a `command -v shuf` guard.

---

## Missing Critical Features

**No work aliases directory:**
- Problem: `zsh/aliases/work/` does not exist. The `zsh/.zshrc:111-115` source loop safely skips missing directories via `(.N)` glob qualifier, so no error occurs. However, adding work-specific aliases requires creating the directory first — this is not documented.
- Blocks: Work profile has no alias customization capability without manual directory creation.
- Fix: Create `zsh/aliases/work/` with a placeholder `.zsh` file, matching the pattern established by `zsh/aliases/personal/`.

**No work functions directory:**
- Problem: `zsh/functions/work/` does not exist. Same safe-skip behavior as above, but work profile users cannot add profile-scoped functions without manual directory creation.
- Blocks: Work profile function customization.
- Fix: Create `zsh/functions/work/` with a placeholder, as with `zsh/functions/personal/` if it exists.

---

## Test Coverage Gaps

**No automated tests for any shell functions or aliases:**
- What's not tested: None of the `zsh/functions/*.zsh` or `zsh/aliases/**/*.zsh` files have associated tests. Breakage in `aliaslist`, `functionlist`, `motd`, `pubkey`, or any other function is only caught manually.
- Files: `zsh/functions/` (all), `zsh/aliases/` (all)
- Risk: Refactoring any shell utility function can silently break it. The `task validate` command checks symlinks and installation state, not functional correctness.
- Priority: Low — typical for dotfiles repos. If test coverage is desired, `zunit` or `bats` can be added.

**`task validate` does not verify the `$DOTFILEDIR` variable is correct in a live shell:**
- What's not tested: `task validate` checks that symlinks exist and point to non-broken targets, but does not verify that sourcing `.zshrc` in a live shell correctly sets `$DOTFILEDIR`. A broken symlink traversal in `.zshrc:75-83` would pass all symlink checks but fail at runtime.
- Files: `taskfiles/links.yml:130-210`, `zsh/.zshrc:75-83`
- Risk: Silent failure of alias/function loading with no validation surface.
- Priority: Medium — add a `validate` step that spawns `zsh -i -c 'echo $DOTFILEDIR'` and checks the output.

---

## Linux/macOS Divergence

**`hardware.zsh` aliases use macOS-only commands with no platform guard:**
- Files: `zsh/aliases/common/hardware.zsh`
- What happens: All 9 aliases in this file use `system_profiler`, `diskutil`, or `sysctl -n machdep.cpu.brand_string` — commands that do not exist on Linux. These are in the `common/` alias directory, not profile-gated, so they load on server profiles.
- Impact: On a Linux server, sourcing `hardware.zsh` defines aliases that will produce "command not found" errors when invoked. No error on source (aliases are lazy), but silent failures at runtime.
- Fix: Move to `zsh/aliases/personal/` or `zsh/aliases/work/` (macOS profiles only), or wrap with `[[ "$(uname)" == "Darwin" ]] && alias ...`.

**`zsh/aliases/common/general.zsh` contains macOS-only aliases in common scope:**
- Files: `zsh/aliases/common/general.zsh:27-31`
- What happens: `finder`, `findershow`, `finderhide` use `open -a Finder` and `defaults write com.apple.finder` — macOS-only commands. They are defined unconditionally in `common/`.
- Impact: Error on invocation from Linux server.
- Fix: Wrap with `[[ "$(uname)" == "Darwin" ]]` guards or relocate to a macOS-only alias file.

**`zsh/aliases/common/networking.zsh` uses `mDNSResponder` DNS flush (macOS-only):**
- Files: `zsh/aliases/common/networking.zsh:4`
- What happens: `dnsflush` alias calls `sudo killall -HUP mDNSResponder` and `dscacheutil -flushcache` — both macOS-only.
- Impact: Silent failure on Linux.
- Fix: Add `[[ "$(uname)" == "Darwin" ]]` guard.

**`zsh/functions/pubkey.zsh` uses `pbcopy` (macOS clipboard, no Linux equivalent):**
- Files: `zsh/functions/pubkey.zsh:11`
- Impact: Silent pipe failure on Linux; the key is not copied.
- Fix: Use `xclip` or `xsel` fallback, or add a platform guard with an echo fallback.

**`claude/hooks/notify.zsh` uses `osascript` for notifications (macOS-only):**
- Files: `claude/hooks/notify.zsh:13`
- What happens: The notification hook silently succeeds (`|| true`) on Linux, but no notification is sent. This is acceptable given Claude Code is a macOS tool, but worth noting.
- Impact: Low — hook exits 0 on failure, so no breakage.

---

*Concerns audit: 2026-05-13*
