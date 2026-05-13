# Stack Research

**Domain:** Manifest-driven dotfiles (macOS-first + first-class Linux servers)
**Researched:** 2026-05-13
**Confidence:** HIGH (all major picks verified against official releases / 2026 docs)

## TL;DR

- **TOML parsing → yq v4.53+** (already in repo; reads TOML natively, no new dep)
- **Plugin manager → antidote v2.1+** (replaces archived Antigen; static bundle; fastest)
- **Prompt → Starship** (Powerlevel10k on life support per its author; cross-shell; sub-200ms target)
- **Cross-platform packages → `brew bundle` with `if OS.mac? / if OS.linux?`** (Homebrew 5.1+ unifies the two platforms)
- **Mac App Store → `mas` entries inside the Brewfile** (no separate Mas-only manifest)
- **Linux native fallback → `apt`/`dnf` for `cloudflared`, `1password-cli`, anything not in linuxbrew-core** (small, explicit, per-machine)
- **Modern CLI utilities → eza, ripgrep, fd, bat, fzf, zoxide, delta, jq** (table stakes; mostly already in repo)
- **Terminal → Ghostty 1.3+** (already in repo; now stable on macOS + Linux/GTK4)

Confidence is HIGH because every recommendation is either (a) already shipping in the current dotfiles repo and being validated daily, or (b) confirmed via 2026 release notes from official sources.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **go-task** | v3.50+ (Apr 2026) | Orchestrator | Locked. Modular includes, `status:` idempotency, dynamic `vars.sh:`, `fromYaml`/`fromJson`/`toJson` templating, parallel deps. |
| **zsh** (Homebrew) | 5.9+ | Primary shell | Locked. Modern globbing, associative arrays, anonymous functions. Homebrew-managed avoids stale system zsh on macOS. |
| **Homebrew** | 5.1+ (Mar 2026) | Cross-platform package manager | Single-source-of-truth for both macOS and Linux servers in 2026. `brew bundle` v5.1 added parallel downloads, auto-tap, Flatpak/Cargo/uv integration. Casks remain macOS-only; formulae work on both. |
| **`brew bundle` (Brewfile)** | Bundled with brew 5.1+ | Declarative package manifest | Native conditional `if OS.mac?` / `if OS.linux?` enables one Brewfile per machine instead of separate `Brewfile.rb` + `apt-packages.txt`. Auto-taps external taps, supports `mas`/`vscode`/`cargo`/`uv`/flatpak entries. |
| **yq (mikefarah)** | v4.53.2+ (Apr 2026) | TOML/YAML/JSON parser | Reads TOML natively (`yq '.path' file.toml`). Writes TOML (`-o toml`) — full roundtrip added in v4.52.1. Single binary already in the repo's Brewfile. Replaces the need for `dasel`, `tq`, `stoml`, or `taplo`. |
| **antidote** | v2.1.0+ (Apr 2026) | Zsh plugin manager | Antigen is archived (last release Jan 2018). Antidote is its explicit successor: feature-complete reimplementation, generates a static plugin bundle file, supports `kind:defer` lazy loading. Faster than zinit in `rossmacarthur/zsh-plugin-manager-benchmark`. |
| **Starship** | latest (Rust, brew-installable) | Cross-shell prompt | Powerlevel10k's author placed it on life support (2025). Starship is actively developed, configured via single `starship.toml`, sub-millisecond render, and (critically) works identically on macOS dev and Linux server — single prompt config per machine via the manifest. |
| **Ghostty** | 1.3.1+ (Mar 2026) | Terminal emulator | Already in the repo. Reached 1.0 Dec 2024; 1.3.x adds scrollback search, native scrollbars, click-to-move-cursor. Native Cocoa on macOS, GTK4 on Linux — covers both target platforms. |
| **1Password CLI + SSH agent** | latest (`1password-cli` cask + GUI app) | Secrets and SSH key store | Manifest gates this behind a `one-password-ssh` feature flag. macOS socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`. Linux socket: `~/.config/1password/agent.sock` (respects `XDG_CONFIG_HOME`). On Linux server profile: system ssh-agent instead. |

### Supporting Libraries / Utilities (CLI Table Stakes 2026)

All available via `brew "<name>"` on both macOS and Linux. These are the unambiguous "modern Unix" baseline confirmed across multiple 2026 reviews and benchmarks.

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **eza** | 0.23.4+ (Oct 2025) | `ls` replacement | Always. Already aliased in `aliases/common/general.zsh`. exa is unmaintained; eza is the community-maintained successor. |
| **bat** | latest | `cat` replacement w/ syntax highlighting | Always. Use `--paging=never` for piping. |
| **ripgrep (rg)** | latest | `grep` replacement | Always for code search. Respects `.gitignore`. PCRE2 build via `brew install ripgrep --with-pcre2` (or just `ripgrep` — pcre2 is default in 2026 bottles). |
| **fd** | latest | `find` replacement | Always. Cleaner syntax, respects `.gitignore`. |
| **fzf** | 0.72.0+ (Apr 2026) | Fuzzy finder | Always. Bind `Ctrl-R` (history), `Ctrl-T` (file), `Alt-C` (directory) via `fzf --zsh`. |
| **zoxide** | 0.9.9+ (Jan 2026) | `cd` replacement (frecency) | Always. Initialize via `eval "$(zoxide init zsh)"`. Aliases `z`/`zi`. |
| **git-delta** | latest | Git pager | Always. Already wired up in `git/config`. |
| **jq** | latest | JSON processor | Required by Claude hook scripts and `taskfiles/claude.yml`. |
| **yq** (see above) | v4.53.2+ | YAML/TOML/JSON | Manifest parsing + general structured-data work. |
| **gh** | latest | GitHub CLI | Repo work; `gh auth login` paired with 1Password SSH agent. |
| **direnv** *(optional)* | latest | Per-directory env | If you want auto-loaded `.envrc`. Not required; manifest handles machine-level config. |
| **atuin** *(optional)* | 18.16.1+ (May 2026) | Shell history with SQLite | Differentiator, not table stakes. Self-hostable sync; encrypted. Skip if you don't want a daemon. |
| **mise** *(optional)* | latest | Polyglot version manager | If/when polyglot dev work needs `.tool-versions` / `.mise.toml`. 10-200× faster than asdf. Replaces both asdf and direnv. Out of scope for v2 but worth a feature flag slot. |
| **shellcheck** | latest | Shell linter | CI/precommit lint of `.sh` and `bash` scripts. Run zsh files through `zsh -n` instead. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **`zsh -n <file>`** | Syntax check zsh scripts | shellcheck does **not** support zsh; this is the official zsh-native check. Run in `task validate` per script. |
| **shellcheck** | Lint POSIX/bash scripts | Use `shellcheck --shell=bash` for ambiguous `.sh` files. Run on `claude/hooks/*.sh` and `bootstrap.zsh` only after rewriting bootstrap as bash-compatible. |
| **`task --list-all`** | Enumerate tasks | Already wired into the repo. Use during development to discover newly added tasks. |
| **`zprof`** | Zsh startup profiler | Built into zsh. Enable in `.zshrc` behind `[[ -n "$DOTFILES_PROFILE_STARTUP" ]] && zmodload zsh/zprof`. Print at end with `zprof`. Use to validate the <200ms cold-start target. |
| **`hyperfine`** | Command benchmarking | For pre/post comparisons of `task install`, `bootstrap.zsh`, and shell-cold-start. `brew install hyperfine`. |

## Installation

### Bootstrap (no `curl | sh`)

```bash
# macOS: install go-task via Homebrew (one-time, manual)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install go-task

# Linux: install go-task via the official install script with checksum verification
#   (or apt/dnf if available; check distro-pinned version isn't too old for v3.50 features)
curl -fsSL https://taskfile.dev/install.sh -o /tmp/task-install.sh
sha256sum /tmp/task-install.sh   # compare against published hash, then:
sh /tmp/task-install.sh -d -b "$HOME/.local/bin"

# From here, go-task is the entrypoint for everything
task setup -- personal-laptop
```

### Per-machine Brewfile composition

```ruby
# install/Brewfile (assembled by go-task from manifest bundles)
tap "homebrew/bundle"

# Core (every machine)
brew "go-task"
brew "zsh"
brew "git"
brew "git-delta"
brew "jq"
brew "yq"
brew "ripgrep"
brew "fd"
brew "bat"
brew "eza"
brew "fzf"
brew "zoxide"
brew "starship"
brew "antidote"
brew "gh"

# macOS-only
brew "mas",                                 if OS.mac?
cask "ghostty",                             if OS.mac?
cask "1password",                           if OS.mac?
cask "1password-cli",                       if OS.mac?
mas  "Magnet", id: 441258766,               if OS.mac?

# Linux-only
brew "openssh",                             if OS.linux?
```

### Manifest-driven assembly

The go-task layer reads `machines/<name>.toml` + `defaults.toml`, merges, then templates the Brewfile, the symlink list, and the macOS-defaults invocation set. yq does the parsing; go-task `vars.sh:` shells out to yq.

```yaml
# taskfiles/manifest.yml (sketch)
vars:
  MANIFEST: '{{.DOTFILEDIR}}/machines/{{.MACHINE}}.toml'
  DEFAULTS: '{{.DOTFILEDIR}}/defaults.toml'

  # Read scalar fields directly from TOML via yq
  PLATFORM:
    sh: yq -r '.platform' "{{.MANIFEST}}"
  FEATURES:
    # Returns a newline-separated list, used with splitLines in tasks
    sh: yq -r '.features[]' "{{.MANIFEST}}"
  BREW_BUNDLES:
    sh: yq -r '.packages.brew_bundles[]' "{{.MANIFEST}}"

tasks:
  has-feature:
    internal: true
    vars:
      FEATURE: '{{.FEATURE}}'
    cmds:
      - |
        if echo "{{.FEATURES}}" | grep -qFx "{{.FEATURE}}"; then
          exit 0
        else
          exit 1
        fi
    silent: true
```

## TOML Parsing: Detailed Recommendation

### Decision: **yq (mikefarah)** — already in your Brewfile

| Tool | Read TOML | Write TOML | Multi-format | Maintained | Already in repo | Verdict |
|------|-----------|------------|--------------|------------|-----------------|---------|
| **yq v4.53+** | Yes (native) | Yes (`-o toml`, roundtrip since v4.52.1) | YAML/JSON/XML/CSV/TOML/HCL | Active (Apr 2026) | **Yes** | **Pick this** |
| dasel v3.9 | Yes | Yes | JSON/YAML/TOML/XML/CSV/HCL/INI | Active (May 2026) | No | Strong alt; only pick if you need INI too |
| taplo CLI 0.10 | Yes (best-of-breed validator) | Yes | TOML only | Active (May 2025) | No | TOML-only; better as formatter/linter than query tool |
| tq / tomlq (cryptaliagy) | Yes | No | TOML only | Maintained | No | Cargo-installed; adds a Rust toolchain dep just for TOML |
| stoml | Yes | No | TOML/INI | **Unmaintained** (last release Oct 2022) | No | Skip |
| `BurntSushi/toml-cli` (`tomlv`) | Validates only | No | TOML | Active | No | Validator, not a query tool |
| go-task native | No (`fromYaml`/`fromJson` only) | No | — | — | — | No TOML support; would require shelling out anyway |

**Rationale for yq over dasel:**

1. **yq is already installed** by your current Brewfile (`brew "jq"` and `brew "yq"`). Adding `dasel` is a new dependency with no offsetting capability.
2. **TOML support is full-roundtrip** in yq 4.52+: read TOML → emit YAML/JSON/TOML.
3. **Single mental model across the whole repo.** Claude hooks already use jq syntax; yq uses the same query language plus a few extensions. Your existing taskfiles already use `jq` extensively (`taskfiles/claude.yml`), so the team's muscle memory is jq-syntax.
4. **dasel's selector syntax is a fourth syntax** to remember alongside jq/yq/bash. The cognitive overhead is not worth the marginal feature gain (INI support, which you don't use).
5. **taplo** is the best-in-class **TOML formatter and validator** — use it as a *complementary* tool in CI (`taplo fmt --check`) for the manifest files, but don't use it for value extraction. You can defer adding it until you actually want manifest format-checking in `task validate`.

**Idiomatic yq usage for the manifest layer:**

```bash
# Scalar
yq -r '.platform' machines/personal-laptop.toml
# → darwin

# Array → newline-separated for bash iteration
yq -r '.features[]' machines/personal-laptop.toml
# → one-password-ssh
#   docker
#   miniconda

# Boolean feature flag
yq -r '.features | contains(["one-password-ssh"])' machines/personal-laptop.toml
# → true

# Merge defaults + machine, then query
yq eval-all '. as $item ireduce ({}; . * $item)' defaults.toml machines/personal-laptop.toml | yq '.packages.brew_bundles[]'

# Convert TOML → JSON for go-task's fromJson templating (cleanest path inside Taskfile)
yq -o=json '.' machines/personal-laptop.toml
```

The **merge-defaults pattern** above is the key one: `yq eval-all` with the reduce expression layers machine over defaults using TOML semantics, then a second yq invocation queries the merged document. This is the same pattern Helm uses for `values.yaml` + override merging — well-understood and battle-tested.

### Loading the merged manifest into go-task as structured data

Two viable patterns:

**Pattern A — sh: per-scalar (simple, current taskfile style):**

```yaml
vars:
  PLATFORM:
    sh: yq -r '.platform' "{{.MANIFEST}}"
  HOSTNAME:
    sh: yq -r '.hostname' "{{.MANIFEST}}"
```

Pro: trivial to read; no template parsing complexity. Con: one yq invocation per field (cheap, but visible in trace mode).

**Pattern B — single sh: emitting JSON, then `fromJson` (more advanced):**

```yaml
vars:
  MANIFEST_JSON:
    sh: yq -o=json eval-all '. as $i ireduce ({}; . * $i)' "{{.DEFAULTS}}" "{{.MANIFEST}}"

tasks:
  install:
    vars:
      MANIFEST: '{{.MANIFEST_JSON | fromJson}}'
      PLATFORM: '{{.MANIFEST.platform}}'
      FEATURES: '{{.MANIFEST.features}}'
    cmds:
      - 'echo platform={{.PLATFORM}}'
      - 'echo features={{.FEATURES}}'
```

Pro: one yq invocation, full structured access. Con: requires understanding of Go template ranging over `{{.MANIFEST.features}}`.

**Recommendation: start with Pattern A.** It matches the current taskfile idiom (sh:-per-var), is trivially debuggable (`task --dry`), and Claude can extend it by reading the template. Migrate to Pattern B only if/when the manifest grows past ~15 fields and the redundant yq calls become a measurable problem.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Homebrew (cross-platform) | apt + dnf native | Only when a package is missing from linuxbrew-core or when a system service must be apt-installed for systemd integration (rare for dev tooling). Document each native-package as an exception in `defaults.toml`. |
| `brew bundle` Brewfile | A custom go-task install loop | If you ever drop Homebrew on Linux. Brewfile gives parallel downloads, auto-tap, `mas`, `cargo`, `vscode`, `uv` for free — replicating that in zsh is wasted work. |
| yq (mikefarah) | dasel | If you adopt INI files heavily, or if dasel's selector syntax appeals more than jq's. No technical reason for the rewrite otherwise. |
| yq (mikefarah) | kislyuk/yq (`tomlq` shim) | If you want strict jq syntax (it shells out to jq). The Python-based wrapper adds a Python dep and is slower than mikefarah/yq's single Go binary. |
| antidote | zinit | If you want **Turbo mode** for async/deferred loading at a finer granularity than antidote's `kind:defer`. Zinit is more powerful but has steeper config and a documented learning curve. Performance benchmarks show antidote winning on cold start, zinit catching up via turbo for interactive prompt-readiness. |
| antidote | sheldon | If you want TOML-configured plugins (sheldon uses `plugins.toml`). Aligns well with the manifest-TOML theme but sheldon is shell-agnostic and adds less value for a zsh-only repo. Last release July 2025 — maintained but slower release cadence. |
| antidote | "unplugged" (no manager) | If you want zero deps and don't mind 10-20 lines of `git clone` + `source` in `.zshrc`. See `mattmc3/zsh_unplugged`. Saves ~5ms on cold start, costs ergonomics. |
| Starship | Powerlevel10k | Only on machines you'll never touch again. p10k is faster *when* configured, but its author has indicated maintenance-only mode. New work should go to Starship. |
| Starship | Pure / spaceship / lean | Only if you want a pure-zsh prompt with zero external binary. All three are slower than Starship and less feature-rich; pick only if Rust binary aversion is real. |
| Ghostty | WezTerm | If you need extensive config-as-Lua and tmux-style multiplexing inside the terminal. WezTerm is more configurable; Ghostty is faster and native. |
| Ghostty | Alacritty / kitty | If you specifically need an X11 build or want minimal config surface. Both are fine, but Ghostty's macOS-native rendering (Metal, ProMotion) is unmatched. |
| 1Password SSH agent | system ssh-agent + `ssh-add` | Mandatory on the server profile (no GUI 1Password). Manifest controls this via the `one-password-ssh` feature flag. |
| brew-installed `mas` | direct App Store downloads | Use `mas` for declarative manifests; manual downloads break re-install idempotency. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Antigen** | Last release Jan 2018 — archived in all but name. Slow startup. Currently in your repo and a primary cause of the ~500ms cold start. | **antidote** (its direct successor) |
| **oh-my-zsh as a framework** | Forces a fat plugin model with heavy startup; loading via antidote-as-source is fine for individual plugins. | Load only the OMZ libs/plugins you actually need via antidote (`getantidote/use-omz`) |
| **Powerlevel10k for new setups** | Author put it on life support (2025). Still works; not where the ecosystem is going. | **Starship** |
| **stoml** | Unmaintained since Oct 2022. | **yq** |
| **dasel** *(in your context)* | Adds a fourth query syntax (jq/yq/bash/dasel). Not technically bad; just unnecessary. | **yq** |
| **`hostname -s` based profile detection** | Documented bug in current `.zprofile` (substring match on "server"). Brittle. | Explicit machine selection persisted in `$XDG_CONFIG_HOME/dotfiles/machine`, set by `task setup -- <name>` |
| **`curl ... \| sh` bootstrap** | Supply-chain risk on every fresh install. Listed as a Constraint in PROJECT.md. | Download to temp, verify sha256, then run |
| **mas authentication via mas signin** | Deprecated by Apple as of 2024 (mas can install but not sign in). User must be signed into App Store manually. | Run `mas install` inside `brew bundle`; document the manual sign-in step in MIGRATION.md |
| **Hardcoded `/opt/homebrew` or `/usr/local`** | Breaks on Intel macOS / Linux. The current repo already detects via `$(brew --prefix)`; preserve this. | `brew --prefix` runtime detection (see `Taskfile.yml` lines 32–39) |
| **conda for non-Python work** | Slow init, no benefit. The current repo already lazy-loads it. | Keep miniconda for actual Python project use; lazy-load. For task automation prefer `uv` (per global CLAUDE.md). |
| **Antibody** | Archived; Antidote is its successor by the same author. | **antidote** |
| **bash for new install scripts** | Already standardized on zsh per CONVENTIONS.md. | zsh with `set -euo pipefail` |
| **`ggrep` for non-PCRE work** | Don't need GNU grep where ripgrep/`grep -E` works. ggrep is reserved for hook scripts that need PCRE2 + portability. | Use `rg` for code search; `grep -E` for simple matches; `ggrep` only in `claude/hooks/*` and security-critical paths |

## Stack Patterns by Variant

**If machine is macOS (personal-laptop, work-laptop):**
- Brewfile installs casks (`1password`, `ghostty`, `docker`, `visual-studio-code`, `raycast`, ...) plus `mas` entries
- 1Password SSH agent socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`
- macOS defaults tasks active (current `taskfiles/macos.yml` patterns)
- Homebrew prefix: `/opt/homebrew` (arm64) or `/usr/local` (x86_64)

**If machine is Linux server (server-1, server-2):**
- Brewfile installs formulae only (`if OS.linux?` guards skip casks/mas)
- 1Password is **not** installed; manifest feature `one-password-ssh = false`
- SSH agent: system `ssh-agent` started by systemd-user-services or `eval $(ssh-agent)` in `.zprofile`
- No macOS defaults tasks
- Homebrew prefix: `/home/linuxbrew/.linuxbrew`
- Native packages (apt/dnf) used only for kernel/system integrations; document each in the manifest's `packages.native` list with a comment justifying why brew isn't sufficient

**If feature `cloudflared` is enabled (any platform):**
- Brewfile: `brew "cloudflared"` (cross-platform formula)
- SSH config: include the `ProxyCommand ~/.ssh/cloudflared.zsh access ssh --hostname %h` block via the `includeIf` mechanism
- jgrid.net aliases enabled (currently in `aliases/personal/jgrid.zsh`)

**If feature `claude-code` is enabled (any platform):**
- Brewfile: `brew "claude"`, `brew "node"`, `brew "jq"`
- Run `npx -y get-shit-done-cc@latest --claude --global` once with a `status:` guard checking `$XDG_CONFIG_HOME/claude/skills/gsd-*/SKILL.md` existence
- Plugin marketplace install with `status:` guard checking `claude/settings.json` `enabledPlugins`

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| go-task v3.50+ | `fromYaml`/`fromJson`/`toJson` since v3.30; map vars since v3.37 | Pin minimum in `Taskfile.yml`: `version: '3'` + a documented "Requires task >= 3.37" preamble. |
| yq v4.53+ | TOML roundtrip since v4.52.1 | Anything older can read but not write TOML — fine if you never emit TOML from go-task. |
| antidote v2.1+ | zsh 5.4+ | Homebrew zsh is well past this. |
| Starship | zsh 5.0+, bash 3.2+ | Universal. |
| Homebrew 5.1+ | macOS 12+ (Monterey), Ubuntu 22.04+, Debian 12+, Fedora 39+ | Older distros work but lose cask/bottle prebuild guarantees. |
| Ghostty 1.3.x | macOS 13+, Linux with GTK4 + libadwaita | Servers headless — don't install on server machines. |
| 1Password 8+ | macOS 12+, Linux (not Flatpak/Snap) | 1Password's Flatpak/Snap builds **cannot** expose the SSH agent — document this if you ever consider Linux desktops. |
| mas-cli | macOS only; App Store login must be manual (mas cannot sign in since 2024) | Brewfile entries still work for `mas install <id>`; just document the one-time sign-in. |

## Notes on go-task Idioms for This Project

1. **`status:` is mandatory.** Every install task gets a working idempotency check. The current repo's `macos:shell` bug (uses `$BREW_ZSH` instead of `{{.BREW_ZSH}}`) is the canonical example of what to fix. Lint convention: any task without `status:` or `internal: true` should be flagged by a `task validate-tasks` meta-task.

2. **`preconditions:` for input validation.** Use `preconditions:` on `task setup -- <machine>` to fail fast if the machine file doesn't exist:
   ```yaml
   preconditions:
     - sh: 'test -f "{{.DOTFILEDIR}}/machines/{{.MACHINE}}.toml"'
       msg: 'Machine manifest not found: machines/{{.MACHINE}}.toml'
   ```

3. **Parallel deps are free.** Tasks listed in `deps:` run in parallel by default. Use this for independent symlink installs (`zsh-links`, `git-links`, `ssh-links` can all run concurrently). Use `serialGroups:` (v4) or explicit `cmds:` chaining (v3) if a shared dependency must run once.

4. **`silent: true` for helper tasks** that don't produce user-facing output. The messaging library (`install/messages.zsh`) handles the structured output; raw echo in helpers is noise.

5. **One taskfile per concern.** Current pattern in `taskfiles/` (brew, macos, links, profile, claude) is good. Add `taskfiles/manifest.yml` for the new TOML parsing layer.

6. **Don't shell out from templates.** go-task's templating runs **before** task execution. Anything you need at task-time should be in `cmds:`, not in `{{...}}` expressions. The `sh:` directive on `vars:` is the documented escape hatch.

## Sources

- [taskfile.dev — Templating Reference](https://taskfile.dev/docs/reference/templating) — confirmed `fromYaml`/`fromJson`/`toJson`/`merge`/`splitLines`; no native TOML reader. HIGH confidence.
- [taskfile.dev — Schema Reference](https://taskfile.dev/docs/reference/schema/) — confirmed `vars.sh:` dynamic variable pattern remains current in v3.x. HIGH.
- [taskfile.dev — Changelog](https://taskfile.dev/changelog/) — confirmed v3.50.0 (Apr 2026) as current. HIGH.
- [github.com/mikefarah/yq](https://github.com/mikefarah/yq) — confirmed v4.53.2 (Apr 2026), full TOML I/O including roundtrip since v4.52.1. HIGH.
- [mikefarah.gitbook.io/yq — Working with TOML](https://mikefarah.gitbook.io/yq/usage/toml) — confirmed read/write/extract patterns. HIGH.
- [github.com/mattmc3/antidote](https://github.com/mattmc3/antidote) — confirmed v2.1.0 (Apr 2026), `kind:defer` lazy loading, antibody/antigen successor. HIGH.
- [github.com/zsh-users/antigen](https://github.com/zsh-users/antigen) — confirmed last release Jan 2018, archived in practice. HIGH.
- [github.com/zdharma-continuum/zinit](https://github.com/zdharma-continuum/zinit) — confirmed v3.14.0 (Apr 2025), Turbo mode, zdharma-continuum maintained. HIGH.
- [github.com/rossmacarthur/zsh-plugin-manager-benchmark](https://github.com/rossmacarthur/zsh-plugin-manager-benchmark) — confirmed performance ranking (antibody/antidote/antigen/sheldon/zimfw top tier; zinit/zplug/zpm bottom). MEDIUM (benchmark conditions noted). HIGH for conclusion that antidote is fast.
- [starship.rs](https://starship.rs/) — confirmed cross-shell, Rust, active. HIGH.
- [hashir.blog — Powerlevel10k on life support](https://hashir.blog/2025/06/powerlevel10k-is-on-life-support-hello-starship/) — community report of p10k maintenance shift; corroborated across multiple 2025-2026 sources. MEDIUM confidence on "life support" (paraphrasing community); HIGH on "Starship is the path forward for new setups."
- [brew.sh — Homebrew 5.1.0](https://brew.sh/2026/03/10/homebrew-5.1.0/) — confirmed `brew bundle` enhancements (parallel downloads, auto-tap, Flatpak/Cargo/uv). HIGH.
- [docs.brew.sh — Brew-Bundle-and-Brewfile](https://docs.brew.sh/Brew-Bundle-and-Brewfile) — confirmed cross-platform `if OS.mac?` / `if OS.linux?` syntax, supported entry types. HIGH.
- [docs.brew.sh — Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) — confirmed first-class Linux support. HIGH.
- [ghostty.org/docs/install/release-notes/1-3-0](https://ghostty.org/docs/install/release-notes/) — confirmed 1.3.0 (Mar 2026) and 1.3.1 stable; macOS + Linux/GTK4. HIGH.
- [developer.1password.com/docs/ssh/agent](https://developer.1password.com/docs/ssh/agent/) — confirmed socket paths on macOS and Linux, XDG support, no-Flatpak/Snap caveat. HIGH.
- [github.com/eza-community/eza](https://github.com/eza-community/eza) — confirmed v0.23.4 (Oct 2025), eza is exa's actively-maintained fork. HIGH.
- [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) — confirmed v0.9.9 (Jan 2026). HIGH.
- [github.com/junegunn/fzf](https://github.com/junegunn/fzf) — confirmed v0.72.0 (Apr 2026). HIGH.
- [github.com/atuinsh/atuin](https://github.com/atuinsh/atuin) — confirmed v18.16.1 (May 2026). HIGH.
- [github.com/TomWright/dasel](https://github.com/tomwright/dasel) — confirmed v3.9.0 (May 2026), active, full multi-format support. HIGH.
- [github.com/tamasfe/taplo](https://github.com/tamasfe/taplo) — confirmed CLI 0.10.0 (May 2025). HIGH.
- [github.com/freshautomations/stoml](https://github.com/freshautomations/stoml) — confirmed unmaintained (last release Oct 2022). HIGH.
- [github.com/rossmacarthur/sheldon](https://github.com/rossmacarthur/sheldon) — confirmed v0.8.5 (Jul 2025), TOML-configured, Rust. HIGH.
- [mise.jdx.dev — Comparison to asdf](https://mise.jdx.dev/dev-tools/comparison-to-asdf.html) — corroborated 10-200× perf claim and direnv-replacement. MEDIUM (mise's own claim); HIGH for "mise is the modern choice."

---
*Stack research for: manifest-driven dotfiles (macOS + Linux), go-task orchestrated*
*Researched: 2026-05-13*
