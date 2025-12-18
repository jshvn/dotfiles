# Go-Task for Dotfiles Management: Complete Analysis

## Executive Summary

This document provides a comprehensive analysis of using [go-task](https://taskfile.dev) (Task) as a replacement for the current zsh-based dotfiles installation process. The primary motivation is enabling **environment-aware configuration** where personal and work systems receive different subsets of aliases, SSH configs, Brew packages, functions, and git configurations.

**TL;DR**: Go-Task is an excellent fit for this use case. It provides declarative task management with built-in dependency resolution, environment variables, conditional execution, and cross-platform support.

---

## Table of Contents

1. [What is Go-Task?](#what-is-go-task)
2. [Pros of Using Go-Task](#pros-of-using-go-task)
3. [Cons of Using Go-Task](#cons-of-using-go-task)
4. [Comparison with Current Zsh-Based Install](#comparison-with-current-zsh-based-install)
5. [Critical Migration Gotchas and Pitfalls](#critical-migration-gotchas-and-pitfalls)
6. [Implementation Plan](#implementation-plan)

---

## What is Go-Task?

[Go-Task](https://taskfile.dev) is a task runner and build tool written in Go. It uses a YAML-based `Taskfile.yml` to define tasks with:

- **Dependencies**: Tasks can depend on other tasks
- **Conditional execution**: Run tasks only when certain conditions are met
- **Variables and templating**: Go template syntax for dynamic configuration
- **Includes**: Split Taskfiles across multiple files
- **Cross-platform**: Single binary, works on macOS, Linux, Windows
- **No external dependencies**: Unlike Make, no shell compatibility issues

### Key Features Relevant to Dotfiles

| Feature | Description | Dotfiles Use Case |
|---------|-------------|-------------------|
| `vars` | Define variables at task/global level | Environment detection (personal/work) |
| `env` | Set environment variables | `DOTFILEDIR`, `XDG_*` paths |
| `deps` | Task dependencies | Ensure XDG dirs exist before linking |
| `preconditions` | Check conditions before running | Verify Homebrew installed |
| `status` | Skip if already done (idempotency) | Skip if symlink exists |
| `includes` | Split into multiple Taskfiles | Separate personal/work configs |
| `platforms` | OS-specific tasks | macOS vs Linux handling |
| `prompt` | Interactive user input | Ask for profile selection |

---

## Pros of Using Go-Task

### 1. **Declarative Configuration**
Your current `install.zsh` is imperative (do A, then B, then C). Task is declarative—you define what needs to happen, and Task figures out the order.

### 2. **Built-in Idempotency via `status`**
The `status` field lets you skip tasks that are already complete:

```yaml
tasks:
  links:zsh:
    cmds:
      - task: safe-link ARGS="{{.DOTFILEDIR}}/zsh/.zshrc,{{.ZDOTDIR}}/.zshrc"
    status:
      - test -L {{.ZDOTDIR}}/.zshrc
```

### 3. **Environment/Profile Support**
Native support for different profiles with persistent storage:

```yaml
vars:
  PROFILE_FILE: '{{.XDG_CONFIG_HOME}}/dotfiles/profile'
  PROFILE:
    sh: cat "{{.PROFILE_FILE}}" 2>/dev/null || echo ""
```

### 4. **Interactive Prompts**
Task 3.x supports interactive prompts for user input.

### 5. **Parallel Execution**
Independent tasks can run in parallel when using `deps`.

### 6. **Self-Documenting**
`task --list` shows all available tasks with descriptions.

---

## Cons of Using Go-Task

### 1. **Additional Dependency**
Task must be installed before the Taskfile can run. This creates a bootstrap problem.

**Mitigation**: `bootstrap.zsh` installs Task directly via the official install script (not Homebrew):
```bash
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

### 2. **No Native Templating for Config Files**
Unlike Chezmoi, Task doesn't template config files.

**Mitigation Options**:
1. Use conditional symlinks (different source files per profile)
2. Use `envsubst` or `sed` in task commands
3. Keep using git's `includeIf` which already handles this

### 3. **Learning Curve**
YAML + Go templates is a different paradigm than shell scripting.

### 4. **Shell Command Limitations**
Complex multi-line shell logic is harder to read in YAML. Long scripts should remain as separate `.zsh` files called by Task.

---

## Comparison with Current Zsh-Based Install

| Aspect | Current Zsh Approach | Go-Task Approach |
|--------|---------------------|------------------|
| **Language** | Pure zsh scripts | YAML + shell commands |
| **Dependencies** | zsh only | Task binary (~8MB) + zsh |
| **Ordering** | Manual (`source` order) | Automatic (DAG resolution) |
| **Idempotency** | Must implement manually | Built-in with `status` |
| **Parallelism** | Sequential only | Built-in parallel execution |
| **Environment Profiles** | Would need custom logic | Native `vars`, `includes` |
| **Error Messages** | Basic shell errors | Rich context + preconditions |
| **Discoverability** | Read the code | `task --list` |
| **Dry Run** | Not available | `task --dry` |
| **Partial Runs** | Run specific script | `task <taskname>` |

---

## Critical Migration Gotchas and Pitfalls

### 1. **DOTFILEDIR Resolution Complexity**

**Current behavior**: Both `install.zsh` and `.zshrc` independently compute `DOTFILEDIR` by following symlinks:

```bash
# install.zsh uses BASH_SOURCE
SOURCE="${BASH_SOURCE[0]}"
while [[ -h "$SOURCE" ]]; do ...

# .zshrc uses zsh-specific ${(%):-%N}
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do ...
```

**Gotcha**: Task runs from the Taskfile directory, so `DOTFILEDIR` resolution is simpler. However, `.zshrc` will still need its own resolution at runtime (Task only handles install-time).

**Solution**: Keep the `.zshrc` resolution logic unchanged. For Task, use:
```yaml
vars:
  DOTFILEDIR:
    sh: cd "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")" && pwd
```

### 2. **Homebrew shellenv Chicken-and-Egg**

**Current behavior**: `brew.zsh` installs Homebrew, then immediately runs `eval "$(brew shellenv)"` to make `brew` available for subsequent commands in the same script.

**Gotcha**: Task runs each `cmd` as a separate shell invocation. Environment changes in one command don't persist to the next.

**Solution**: Chain commands in a single `cmd` block or explicitly eval shellenv at the start of each block that needs brew:

```yaml
tasks:
  brew:bundle:
    cmds:
      - |
        # Evaluate shellenv for this command block
        if [[ "$(uname -m)" == "arm64" ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        else
          eval "$(/usr/local/bin/brew shellenv)"
        fi
        brew update && brew upgrade
        brew bundle --file {{.DOTFILEDIR}}/install/Brewfile.rb
```

### 3. **sudo and Interactive Prompts**

**Current behavior**: `defaults.zsh` and `zdotdir.zsh` use `sudo` for system-level changes.

**Gotcha**: Multiple `sudo` calls may prompt multiple times if the sudo timeout expires.

**Solution**: Refresh sudo upfront at the start of install:
```yaml
tasks:
  install:
    cmds:
      - sudo -v  # Refresh sudo timestamp upfront
      - task: xdg
      # ... rest of tasks
```

### 4. **Antigen and oh-my-zsh Dependencies**

**Current behavior**: `.zshrc` sources antigen from `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`. This only works after Homebrew is installed.

**Gotcha**: If you run a partial install (e.g., just `task links`), then open a new shell, `.zshrc` will fail because antigen isn't installed yet.

**Solution**: Add a guard in `.zshrc`:

```bash
if [[ -f "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh"
  # ... antigen bundles
else
  echo "Warning: antigen not found. Run 'task install' to complete setup."
fi
```

### 5. **The `update()` Function Integration**

**Current behavior**: `zsh/functions/update.zsh` defines an `update()` function that runs `zsh "$DOTFILEDIR/install.zsh"`.

**Gotcha**: The function must call `task` instead of `install.zsh`, but `task` must be in PATH.

**Solution**: Modify `update()` to call `task update`:
```bash
function update() {
  local currentdir=$(pwd)
  cd "$DOTFILEDIR"
  git pull
  task update  # Task handles the rest
  cd "$currentdir"
}
```

### 6. **Profile Persistence Location**

**Requirement**: Store profile in `${XDG_CONFIG_HOME}/dotfiles/profile`

**Gotcha**: During first install, XDG_CONFIG_HOME directory may not exist yet.

**Solution**: The profile prompt task must first ensure the directory exists:
```yaml
tasks:
  profile:ensure:
    cmds:
      - mkdir -p "{{.XDG_CONFIG_HOME}}/dotfiles"
      - |
        if [[ ! -f "{{.PROFILE_FILE}}" ]]; then
          # prompt for profile selection
        fi
```

### 7. **safe_link Function Equivalent**

**Current behavior**: `links.zsh` has a `safe_link()` function that creates parent directories before symlinking.

**Gotcha**: Task doesn't have functions, but you can create a reusable internal task.

**Solution**: Create a `safe-link` internal task:
```yaml
tasks:
  safe-link:
    internal: true
    requires:
      vars: [SOURCE, TARGET]
    cmds:
      - mkdir -p "$(dirname "{{.TARGET}}")"
      - ln -sf "{{.SOURCE}}" "{{.TARGET}}"
```

### 8. **Variable Expansion Timing**

**Gotcha**: Task variables with `sh:` are evaluated at parse time, not runtime. This matters for variables that depend on files created by previous tasks.

**Example Problem**:
```yaml
vars:
  PROFILE:
    sh: cat {{.XDG_CONFIG_HOME}}/dotfiles/profile  # Evaluated BEFORE profile:prompt runs!
```

**Solution**: Read the profile in the task that needs it, using shell commands:
```yaml
tasks:
  profile:install:
    cmds:
      - |
        PROFILE=$(cat "{{.PROFILE_FILE}}")
        task "${PROFILE}:install"
```

### 9. **Alias/Function Runtime Loading**

**Current behavior**: `.zshrc` loops through `$DOTFILEDIR/zsh/aliases/*.zsh` and sources all files.

**Gotcha**: If you want profile-specific aliases, the runtime loading logic in `.zshrc` needs to be profile-aware, NOT just the install-time symlinking.

**Solution**: Runtime filtering based on profile file:
```bash
PROFILE=$(cat "${XDG_CONFIG_HOME}/dotfiles/profile" 2>/dev/null || echo "personal")

# Load common aliases
for file in "$DOTFILEDIR/zsh/aliases/common/"*.zsh(.N); do
  source "$file"
done

# Load profile-specific aliases
for file in "$DOTFILEDIR/profiles/${PROFILE}/aliases/"*.zsh(.N); do
  source "$file"
done
```

### 10. **set -e Behavior Differences**

**Current behavior**: `install.zsh` uses `set -e` to abort on first error.

**Gotcha**: Task commands don't inherit `set -e` by default.

**Solution**: Task stops on error by default. For complex shell blocks, explicitly add `set -e`:
```yaml
cmds:
  - |
    set -e
    command1
    command2
```

---

## Implementation Plan

This plan is designed to be executed sequentially. Each step builds on the previous.

### Directory Structure After Migration

```
dotfiles/
├── bootstrap.zsh             # New: installs Task, runs task install
├── Taskfile.yml              # New: main taskfile
├── taskfiles/                # New: split taskfiles
│   ├── common.yml            # XDG, ZDOTDIR, shared utilities
│   ├── profile.yml           # Profile detection and prompting
│   ├── links.yml             # All symlink tasks + safe-link helper
│   ├── brew.yml              # Homebrew install and bundle
│   ├── macos.yml             # macOS-specific (defaults, xcode, shell)
│   ├── personal.yml          # Personal profile tasks
│   └── work.yml              # Work profile tasks
├── docs/                     # Keep: documentation
├── git/                      # Keep as-is (includeIf handles profiles)
│   ├── config
│   ├── ignore
│   ├── personal/
│   │   └── config-personal
│   └── work/
│       └── config-work
├── install/                  # Keep: installation files + profile Brewfiles
│   ├── Brewfile.rb           # Common packages (all profiles)
│   ├── personal/
│   │   └── Brewfile.rb       # Personal-only packages
│   ├── work/
│   │   └── Brewfile.rb       # Work-only packages
│   ├── brew.zsh              # Deprecated (kept for reference)
│   ├── defaults.zsh          # Deprecated (kept for reference)
│   ├── links.zsh             # Deprecated (kept for reference)
│   └── ...
├── ssh/                      # Keep as-is (already has personal/work structure)
│   ├── configs/
│   │   ├── config
│   │   ├── agent.toml
│   │   ├── personal/
│   │   │   └── config_personal
│   │   └── work/
│   │       └── config_work
│   └── keys/
│       └── id_ed25519_personal.pub
└── zsh/                      # Keep structure, add profile subdirs where needed
    ├── .zshenv
    ├── .zprofile
    ├── .zshrc
    ├── .zlogin
    ├── .zlogout
    ├── theme.zsh
    ├── aliases/              # Profile separation via subdirectories
    │   ├── common/           # Always loaded
    │   │   ├── general.zsh
    │   │   ├── hardware.zsh
    │   │   └── networking.zsh
    │   ├── personal/         # Personal-only aliases
    │   │   └── jgrid.zsh
    │   └── work/             # Work-only aliases
    │       └── (empty or work-specific)
    ├── configs/              # No profile separation needed (keep flat)
    │   ├── condarc
    │   ├── ghostty
    │   ├── glow.yml
    │   └── ...
    ├── functions/            # Profile separation if needed
    │   ├── afk.zsh           # Common functions at this level
    │   ├── update.zsh        # (or use common/ subdir if preferred)
    │   ├── ...
    │   ├── personal/         # Personal-only functions (optional)
    │   │   └── motd.zsh      # If JGRID branding is personal-only
    │   └── work/             # Work-only functions (optional)
    └── styles/               # No profile separation needed (keep flat)
        ├── eza_style.yaml
        └── glow_style.json
```

**Key Structural Decisions**:

1. **install/**: Brewfiles organized as `install/Brewfile.rb` (common), `install/personal/Brewfile.rb`, `install/work/Brewfile.rb`

2. **zsh/aliases/**: Uses `common/`, `personal/`, `work/` subdirectories since jgrid.zsh is personal-only

3. **zsh/functions/**: Common functions stay at the top level; profile-specific functions go in `personal/` or `work/` subdirectories (optional)

4. **zsh/configs/** and **zsh/styles/**: No profile separation needed, keep flat structure

5. **git/** and **ssh/**: Already have profile separation, keep as-is

---

### Step 0: Create Directory Structure

**Purpose**: Create the new directory structure before any other steps. This ensures all paths exist.

**Run these commands from the dotfiles root**:

```bash
# Create taskfiles directory
mkdir -p taskfiles

# Create profile subdirectories for install (Brewfiles)
mkdir -p install/personal
mkdir -p install/work

# Create profile subdirectories for zsh/aliases
mkdir -p zsh/aliases/common
mkdir -p zsh/aliases/personal
mkdir -p zsh/aliases/work

# Create profile subdirectories for zsh/functions (optional, only if you want profile-specific functions)
mkdir -p zsh/functions/personal
mkdir -p zsh/functions/work

# Create empty profile Brewfiles
touch install/personal/Brewfile.rb
touch install/work/Brewfile.rb
```

**Then move existing alias files**:

```bash
# Move common aliases to common/ subdirectory
mv zsh/aliases/general.zsh zsh/aliases/common/
mv zsh/aliases/hardware.zsh zsh/aliases/common/
mv zsh/aliases/networking.zsh zsh/aliases/common/

# Move personal-only aliases to personal/ subdirectory
mv zsh/aliases/jgrid.zsh zsh/aliases/personal/

# Optional: Move motd.zsh to personal-only (if you want JGRID branding personal-only)
# mv zsh/functions/motd.zsh zsh/functions/personal/
```

**Important**: After moving files, the `zsh/aliases/` directory should only contain the subdirectories (`common/`, `personal/`, `work/`). Delete any remaining files at the top level.

---

### Step 1: Create bootstrap.zsh

**File**: `bootstrap.zsh`

**Purpose**: Entry point for fresh installs. Installs Task directly (not via Homebrew), then runs `task install`.

```bash
#!/bin/zsh
set -e

echo "$(tput setaf 2)Dotfiles Bootstrap$(tput sgr0)"
echo ""

# Resolve DOTFILEDIR (same logic as install.zsh)
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# Install go-task if not present
if ! command -v task &> /dev/null; then
  echo "Installing go-task..."
  
  # Determine install location based on permissions
  if [[ -w /usr/local/bin ]]; then
    INSTALL_DIR="/usr/local/bin"
  else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    export PATH="$INSTALL_DIR:$PATH"
  fi
  
  # Install Task via official install script
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b "$INSTALL_DIR"
  
  echo "go-task installed to $INSTALL_DIR"
fi

# Run task install with any passed arguments
cd "$DOTFILEDIR"
task install "$@"
```

---

### Step 2: Create Main Taskfile.yml

**File**: `Taskfile.yml`

**Purpose**: Main entry point, defines global variables, includes sub-taskfiles.

```yaml
version: '3'

vars:
  # Core paths
  HOME: '{{.HOME}}'
  XDG_CONFIG_HOME: '{{.HOME}}/.config'
  XDG_DATA_HOME: '{{.HOME}}/.local/share'
  XDG_STATE_HOME: '{{.HOME}}/.local/state'
  XDG_CACHE_HOME: '{{.HOME}}/.cache'
  ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'
  
  # Dotfiles paths
  DOTFILEDIR:
    sh: cd "$(dirname "$(realpath "${BASH_SOURCE[0]:-$0}")")" 2>/dev/null && pwd || pwd
  PROFILE_FILE: '{{.XDG_CONFIG_HOME}}/dotfiles/profile'
  
  # Profile - read from file, empty if not set (evaluated at parse time)
  PROFILE:
    sh: cat "{{.XDG_CONFIG_HOME}}/dotfiles/profile" 2>/dev/null || echo ""
  
  # Homebrew prefix - defined here so all taskfiles can access it
  HOMEBREW_PREFIX:
    sh: |
      if [[ "$(uname)" == "Darwin" ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
          echo "/opt/homebrew"
        else
          echo "/usr/local"
        fi
      else
        echo "/home/linuxbrew/.linuxbrew"
      fi

includes:
  common: ./taskfiles/common.yml
  profile: ./taskfiles/profile.yml
  links: ./taskfiles/links.yml
  brew: ./taskfiles/brew.yml
  macos: ./taskfiles/macos.yml
  personal:
    taskfile: ./taskfiles/personal.yml
    optional: true
  work:
    taskfile: ./taskfiles/work.yml
    optional: true

tasks:
  default:
    desc: "Show available tasks"
    silent: true
    cmds:
      - task --list

  install:
    desc: "Full dotfiles installation"
    summary: |
      Installs all dotfiles components for the configured profile.
      
      Usage:
        ./bootstrap.zsh              # Fresh install (prompts for profile)
        task install                 # Re-install with saved profile
        task install PROFILE=work    # Override profile for this run
    cmds:
      - sudo -v  # Refresh sudo upfront for steps that need it
      - task: common:xdg
      - task: profile:ensure
      - task: common:zdotdir
      - task: links:all
      - task: brew:install
      - task: macos:xcode
      - task: macos:defaults
      - task: macos:shell
      - task: profile:install
      - echo ""
      - echo "$(tput setaf 2)✓ Installation complete for profile: $(cat {{.PROFILE_FILE}})$(tput sgr0)"

  update:
    desc: "Update dotfiles and all dependencies"
    summary: |
      Updates the dotfiles installation:
        - Pulls latest from git
        - Updates Homebrew packages
        - Updates oh-my-zsh
        - Updates tldr definitions
        - Updates antigen plugins
        - Re-runs profile installation
    cmds:
      - task: profile:require
      - echo "$(tput setaf 6)Updating dotfiles...$(tput sgr0)"
      - git pull
      - task: brew:update
      - zsh -c 'source "$ZSH/tools/upgrade.sh"' 2>/dev/null || true
      - tldr --update 2>/dev/null || true
      - task: common:antigen-update
      - task: profile:install
      - echo "$(tput setaf 2)✓ Update complete$(tput sgr0)"

  validate:
    desc: "Validate dotfiles installation"
    cmds:
      - echo "Validating installation..."
      - test -L {{.ZDOTDIR}}/.zshrc && echo "✓ zsh config linked" || echo "✗ zsh config missing"
      - test -L {{.XDG_CONFIG_HOME}}/git/config && echo "✓ git config linked" || echo "✗ git config missing"
      - test -L {{.HOME}}/.ssh/config && echo "✓ ssh config linked" || echo "✗ ssh config missing"
      - command -v eza &>/dev/null && echo "✓ eza installed" || echo "✗ eza missing"
      - command -v glow &>/dev/null && echo "✓ glow installed" || echo "✗ glow missing"
      - echo "Profile: $(cat {{.PROFILE_FILE}} 2>/dev/null || echo 'not set')"

  clean:
    desc: "Remove caches and generated files"
    cmds:
      - rm -rf {{.XDG_CACHE_HOME}}/antigen
      - rm -rf {{.XDG_CACHE_HOME}}/zsh
      - echo "Cleaned caches"
```

---

### Step 3: Create taskfiles/common.yml

**File**: `taskfiles/common.yml`

**Purpose**: XDG directories, ZDOTDIR setup, shared utilities.

```yaml
version: '3'

tasks:
  xdg:
    desc: "Create XDG base directories"
    cmds:
      - echo "Ensuring XDG Base Directories exist..."
      - mkdir -p "{{.XDG_CONFIG_HOME}}"
      - mkdir -p "{{.XDG_DATA_HOME}}"
      - mkdir -p "{{.XDG_STATE_HOME}}"
      - mkdir -p "{{.XDG_CACHE_HOME}}"
    status:
      - test -d "{{.XDG_CONFIG_HOME}}"
      - test -d "{{.XDG_DATA_HOME}}"
      - test -d "{{.XDG_STATE_HOME}}"
      - test -d "{{.XDG_CACHE_HOME}}"

  zdotdir:
    desc: "Configure ZDOTDIR in /etc/zshenv"
    cmds:
      - |
        ZDOTDIR_EXPORT='export ZDOTDIR="{{.ZDOTDIR}}"'
        if [[ ! -f /etc/zshenv ]]; then
          echo "Creating /etc/zshenv with ZDOTDIR export..."
          echo "$ZDOTDIR_EXPORT" | sudo tee /etc/zshenv > /dev/null
        elif ! grep -qF "$ZDOTDIR_EXPORT" /etc/zshenv; then
          echo "Adding ZDOTDIR export to /etc/zshenv..."
          echo "$ZDOTDIR_EXPORT" | sudo tee -a /etc/zshenv > /dev/null
        else
          echo "ZDOTDIR already configured in /etc/zshenv"
        fi

  antigen-update:
    desc: "Update Antigen plugins"
    cmds:
      - |
        if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" ]]; then
          zsh -c 'source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" && antigen update'
        else
          echo "Antigen not installed, skipping update"
        fi
```

---

### Step 4: Create taskfiles/profile.yml

**File**: `taskfiles/profile.yml`

**Purpose**: Profile detection, prompting, and persistence.

```yaml
version: '3'

vars:
  VALID_PROFILES: "personal work"

tasks:
  ensure:
    desc: "Ensure profile is set, prompt if missing"
    cmds:
      - mkdir -p "$(dirname "{{.PROFILE_FILE}}")"
      - |
        if [[ ! -f "{{.PROFILE_FILE}}" ]] || [[ -z "$(cat "{{.PROFILE_FILE}}" 2>/dev/null)" ]]; then
          echo ""
          echo "$(tput setaf 3)No profile configured. Please select one:$(tput sgr0)"
          echo ""
          echo "  $(tput setaf 6)1)$(tput sgr0) personal - Personal machine (includes jgrid aliases, personal SSH keys)"
          echo "  $(tput setaf 6)2)$(tput sgr0) work     - Work machine (work-specific configs)"
          echo ""
          while true; do
            read -p "Enter choice [1-2]: " choice
            case $choice in
              1) echo "personal" > "{{.PROFILE_FILE}}"; break ;;
              2) echo "work" > "{{.PROFILE_FILE}}"; break ;;
              *) echo "Invalid choice. Please enter 1 or 2." ;;
            esac
          done
          echo ""
          echo "$(tput setaf 2)Profile set to: $(cat "{{.PROFILE_FILE}}")$(tput sgr0)"
        else
          echo "Profile: $(cat "{{.PROFILE_FILE}}")"
        fi

  require:
    desc: "Require profile to be set (fail if not)"
    preconditions:
      - sh: test -f "{{.PROFILE_FILE}}" && test -n "$(cat "{{.PROFILE_FILE}}")"
        msg: "Profile not set. Run 'task install' or 'task profile:set PROFILE=personal'"

  set:
    desc: "Set profile (use PROFILE=personal or PROFILE=work)"
    cmds:
      - mkdir -p "$(dirname "{{.PROFILE_FILE}}")"
      - |
        if [[ -z "{{.PROFILE}}" ]]; then
          echo "Error: PROFILE variable required. Use: task profile:set PROFILE=personal"
          exit 1
        fi
        if [[ ! " {{.VALID_PROFILES}} " =~ " {{.PROFILE}} " ]]; then
          echo "Error: Invalid profile '{{.PROFILE}}'. Must be one of: {{.VALID_PROFILES}}"
          exit 1
        fi
        echo "{{.PROFILE}}" > "{{.PROFILE_FILE}}"
        echo "Profile set to: {{.PROFILE}}"

  show:
    desc: "Show current profile"
    cmds:
      - |
        if [[ -f "{{.PROFILE_FILE}}" ]]; then
          echo "Current profile: $(cat "{{.PROFILE_FILE}}")"
        else
          echo "No profile set"
        fi

  install:
    desc: "Run profile-specific installation"
    cmds:
      - |
        PROFILE=$(cat "{{.PROFILE_FILE}}")
        echo "Running installation for profile: $PROFILE"
        task "${PROFILE}:install"
```

---

### Step 5: Create taskfiles/links.yml

**File**: `taskfiles/links.yml`

**Purpose**: All symlink operations with safe_link helper.

```yaml
version: '3'

tasks:
  # Helper task that replicates safe_link() function
  # Creates parent directory if needed, then creates symlink
  safe-link:
    internal: true
    requires:
      vars: [SOURCE, TARGET]
    cmds:
      - mkdir -p "$(dirname "{{.TARGET}}")"
      - ln -sf "{{.SOURCE}}" "{{.TARGET}}"

  all:
    desc: "Create all symlinks"
    cmds:
      - task: zsh
      - task: git
      - task: ssh
      - task: tools

  zsh:
    desc: "Link zsh configuration files"
    cmds:
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zprofile", TARGET: "{{.ZDOTDIR}}/.zprofile" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zshrc", TARGET: "{{.ZDOTDIR}}/.zshrc" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zlogin", TARGET: "{{.ZDOTDIR}}/.zlogin" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/.zlogout", TARGET: "{{.ZDOTDIR}}/.zlogout" }
    status:
      - test -L "{{.ZDOTDIR}}/.zshrc"

  git:
    desc: "Link git configuration files (common)"
    cmds:
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/git/config", TARGET: "{{.XDG_CONFIG_HOME}}/git/config" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/git/ignore", TARGET: "{{.XDG_CONFIG_HOME}}/git/ignore" }
    status:
      - test -L "{{.XDG_CONFIG_HOME}}/git/config"

  ssh:
    desc: "Link SSH configuration files (common)"
    cmds:
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/ssh/configs/config", TARGET: "{{.HOME}}/.ssh/config" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/ssh/cloudflared.zsh", TARGET: "{{.HOME}}/.ssh/cloudflared.zsh" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/ssh/configs/agent.toml", TARGET: "{{.XDG_CONFIG_HOME}}/1Password/ssh/agent.toml" }
    status:
      - test -L "{{.HOME}}/.ssh/config"

  tools:
    desc: "Link tool configuration files"
    cmds:
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/configs/trippy.toml", TARGET: "{{.XDG_CONFIG_HOME}}/trippy/trippy.toml" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/configs/tlrc.toml", TARGET: "{{.XDG_CONFIG_HOME}}/tlrc/config.toml" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/styles/eza_style.yaml", TARGET: "{{.XDG_CONFIG_HOME}}/eza/theme.yaml" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/configs/condarc", TARGET: "{{.XDG_CONFIG_HOME}}/conda/condarc" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/configs/ghostty", TARGET: "{{.XDG_CONFIG_HOME}}/ghostty/config" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/configs/glow.yml", TARGET: "{{.XDG_CONFIG_HOME}}/glow/glow.yml" }
      - task: safe-link
        vars: { SOURCE: "{{.DOTFILEDIR}}/zsh/styles/glow_style.json", TARGET: "{{.XDG_CONFIG_HOME}}/glow/glow_style.json" }
```

---

### Step 6: Create taskfiles/brew.yml

**File**: `taskfiles/brew.yml`

**Purpose**: Homebrew installation, package management, updates.

**Note**: `HOMEBREW_PREFIX` is defined in the root `Taskfile.yml` and inherited by all taskfiles.

```yaml
version: '3'

tasks:
  install:
    desc: "Install Homebrew and packages"
    cmds:
      - task: ensure-homebrew
      - task: bundle

  ensure-homebrew:
    desc: "Install Homebrew if not present"
    cmds:
      - |
        if ! command -v brew &> /dev/null; then
          echo "Installing Homebrew..."
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
          
          # Load Homebrew into current environment
          eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
        else
          echo "Homebrew already installed"
        fi
    status:
      - command -v brew

  bundle:
    desc: "Install packages from Brewfile"
    deps: [ensure-homebrew]
    cmds:
      - |
        # Ensure brew is in PATH for this command
        eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
        
        echo "Updating Homebrew..."
        brew update
        brew upgrade
        brew cleanup --prune=30
        
        echo "Installing packages from Brewfile..."
        brew bundle --file "{{.DOTFILEDIR}}/install/Brewfile.rb"
        
        # Install profile-specific Brewfile if exists
        PROFILE=$(cat "{{.PROFILE_FILE}}" 2>/dev/null)
        if [[ -n "$PROFILE" && -f "{{.DOTFILEDIR}}/install/$PROFILE/Brewfile.rb" ]]; then
          echo "Installing $PROFILE profile packages..."
          brew bundle --file "{{.DOTFILEDIR}}/install/$PROFILE/Brewfile.rb"
        fi

  update:
    desc: "Update Homebrew and all packages"
    cmds:
      - |
        eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
        brew update
        brew upgrade
        brew cleanup --prune=30
```

---

### Step 7: Create taskfiles/macos.yml

**File**: `taskfiles/macos.yml`

**Purpose**: macOS-specific tasks (Xcode, defaults, shell setup).

```yaml
version: '3'

tasks:
  xcode:
    desc: "Install Xcode command line tools"
    platforms: [darwin]
    cmds:
      - |
        if xcode-select -p &>/dev/null; then
          echo "Xcode Command Line Tools already installed"
        else
          echo "Installing Xcode Command Line Tools..."
          xcode-select --install
          # Wait for installation to complete
          until xcode-select -p &>/dev/null; do
            sleep 5
          done
          sudo xcodebuild -license accept
        fi
    status:
      - xcode-select -p &>/dev/null

  defaults:
    desc: "Apply macOS system defaults"
    platforms: [darwin]
    cmds:
      - |
        # Quit System Preferences if open
        osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
        
        echo "Applying macOS defaults..."
        
        # Security
        defaults write com.apple.screensaver askForPassword -int 1
        defaults write com.apple.screensaver askForPasswordDelay -int 0
        
        # Dock
        defaults write com.apple.dock orientation -string "bottom"
        defaults write com.apple.dock tilesize -int 45
        defaults write com.apple.dock autohide -bool true
        defaults write com.apple.dock mineffect -string "genie"
        defaults write com.apple.dock show-recents -bool true
        defaults write com.apple.dock mru-spaces -bool false
        
        # Appearance
        defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
        defaults write -g com.apple.swipescrolldirection -bool false
        
        # Finder
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
        defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
        
        # Photos - don't open on device connect
        defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
        
        # Finder icon arrangement
        /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null || true
        
        # Disable guest account if enabled
        if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
          echo "Disabling guest account..."
          sudo sysadminctl -guestAccount off
        fi
        
        # Menu bar items
        defaults write com.apple.TextInputMenu visible -bool false
        defaults write com.apple.Siri StatusMenuVisible -bool false
        
        echo "Defaults applied. Some changes require logout/restart."

  shell:
    desc: "Set Homebrew zsh as default shell"
    platforms: [darwin]
    vars:
      BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'
    cmds:
      - |
        BREW_ZSH="{{.BREW_ZSH}}"
        
        # Ensure brew is available
        eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
        
        # Add to /etc/shells if not present
        if ! grep -qxF "$BREW_ZSH" /etc/shells; then
          echo "Adding $BREW_ZSH to /etc/shells..."
          echo "$BREW_ZSH" | sudo tee -a /etc/shells
        fi
        
        # Note: Not auto-changing shell as this requires logout
        echo "Homebrew zsh is available at $BREW_ZSH"
        echo "To set as default: chsh -s $BREW_ZSH"
```

---

### Step 8: Create taskfiles/personal.yml

**File**: `taskfiles/personal.yml`

**Purpose**: Personal profile-specific installation.

```yaml
version: '3'

tasks:
  install:
    desc: "Install personal profile configurations"
    cmds:
      - echo "Installing personal profile..."
      - task: links
      - task: brew
      - echo "$(tput setaf 2)Personal profile configured$(tput sgr0)"

  links:
    desc: "Create personal-specific symlinks"
    cmds:
      # Git personal config
      - task: links:safe-link
        vars: 
          SOURCE: "{{.DOTFILEDIR}}/git/personal/config-personal"
          TARGET: "{{.XDG_CONFIG_HOME}}/git/personal/config-personal"
      
      # SSH personal config and keys
      - task: links:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/ssh/configs/personal/config_personal"
          TARGET: "{{.HOME}}/.ssh/config_personal"
      - task: links:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/ssh/keys/id_ed25519_personal.pub"
          TARGET: "{{.HOME}}/.ssh/id_ed25519_personal.pub"

  brew:
    desc: "Install personal-specific Homebrew packages"
    cmds:
      - |
        if [[ -f "{{.DOTFILEDIR}}/install/personal/Brewfile.rb" ]]; then
          eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
          brew bundle --file "{{.DOTFILEDIR}}/install/personal/Brewfile.rb"
        fi
```

---

### Step 9: Create taskfiles/work.yml

**File**: `taskfiles/work.yml`

**Purpose**: Work profile-specific installation.

```yaml
version: '3'

tasks:
  install:
    desc: "Install work profile configurations"
    cmds:
      - echo "Installing work profile..."
      - task: links
      - task: brew
      - echo "$(tput setaf 2)Work profile configured$(tput sgr0)"

  links:
    desc: "Create work-specific symlinks"
    cmds:
      # Git work config
      - task: links:safe-link
        vars:
          SOURCE: "{{.DOTFILEDIR}}/git/work/config-work"
          TARGET: "{{.XDG_CONFIG_HOME}}/git/work/config-work"
      
      # SSH work config if exists
      - |
        if [[ -f "{{.DOTFILEDIR}}/ssh/configs/work/config_work" ]]; then
          mkdir -p "{{.HOME}}/.ssh"
          ln -sf "{{.DOTFILEDIR}}/ssh/configs/work/config_work" "{{.HOME}}/.ssh/config_work"
        fi

  brew:
    desc: "Install work-specific Homebrew packages"
    cmds:
      - |
        if [[ -f "{{.DOTFILEDIR}}/install/work/Brewfile.rb" ]]; then
          eval "$({{.HOMEBREW_PREFIX}}/bin/brew shellenv)"
          brew bundle --file "{{.DOTFILEDIR}}/install/work/Brewfile.rb"
        fi
```

---

### Step 10: Restructure Aliases for Profile Support

**Current structure**:
```
zsh/aliases/
├── general.zsh
├── hardware.zsh
├── jgrid.zsh      # Personal only
└── networking.zsh
```

**New structure**:
```
zsh/aliases/
├── common/           # Always loaded
│   ├── general.zsh
│   ├── hardware.zsh
│   └── networking.zsh
├── personal/         # Personal-only aliases
│   └── jgrid.zsh
└── work/             # Work-only aliases
    └── (work-specific aliases)
```

**Note**: This keeps all alias files within `zsh/aliases/` with profile separation via subdirectories.

**Actions** (already done in Step 0, listed here for reference):
1. Create `zsh/aliases/common/` directory
2. Move `general.zsh`, `hardware.zsh`, `networking.zsh` to `common/`
3. Create `zsh/aliases/personal/` and move `jgrid.zsh` there
4. Create `zsh/aliases/work/` (empty for now)

---

### Step 11: Update .zshrc for Profile-Aware Loading

**File**: `zsh/.zshrc`

**IMPORTANT**: This step REPLACES existing code. Do not duplicate.

**Find and REMOVE these lines** (around line 100-113):

```bash
# ❌ REMOVE THIS BLOCK:
# load ZSH aliases
for file in "$DOTFILEDIR/zsh/aliases/"*.zsh(.N); do
    source "$file"
done

# load common ZSH custom themes
source $DOTFILEDIR/zsh/theme.zsh

# load ZSH function and helper scripts
for file in "$DOTFILEDIR/zsh/functions/"*.zsh(.N); do
    source "$file"
done
```

**Replace with this new block** (in the same location):

```bash
# ✅ NEW PROFILE-AWARE LOADING:

# Read current profile (default to personal if not set)
DOTFILES_PROFILE=$(cat "${XDG_CONFIG_HOME}/dotfiles/profile" 2>/dev/null || echo "personal")
export DOTFILES_PROFILE

# Load common aliases (from zsh/aliases/common/)
for file in "$DOTFILEDIR/zsh/aliases/common/"*.zsh(.N); do
    source "$file"
done

# Load profile-specific aliases (from zsh/aliases/$PROFILE/)
if [[ -d "$DOTFILEDIR/zsh/aliases/$DOTFILES_PROFILE" ]]; then
    for file in "$DOTFILEDIR/zsh/aliases/$DOTFILES_PROFILE/"*.zsh(.N); do
        source "$file"
    done
fi

# Load common theme
source "$DOTFILEDIR/zsh/theme.zsh"

# Load common functions (from zsh/functions/*.zsh, excluding subdirectories)
for file in "$DOTFILEDIR/zsh/functions/"*.zsh(.N); do
    source "$file"
done

# Load profile-specific functions (from zsh/functions/$PROFILE/)
if [[ -d "$DOTFILEDIR/zsh/functions/$DOTFILES_PROFILE" ]]; then
    for file in "$DOTFILEDIR/zsh/functions/$DOTFILES_PROFILE/"*.zsh(.N); do
        source "$file"
    done
fi
```

**Note**: Common functions remain at `zsh/functions/*.zsh` (top level), profile-specific functions go in `zsh/functions/personal/` or `zsh/functions/work/`.

---

### Step 12: Update update.zsh Function

**File**: `zsh/functions/update.zsh`

**Replace entire content with**:

```bash
#!/bin/zsh

# update() will update the current dotfiles installation and dependencies
function update() {
    # Save current directory
    local currentdir=$(pwd)

    # Navigate to dotfile install directory
    cd "$DOTFILEDIR"

    # Pull latest changes
    git pull

    # Run task update (handles oh-my-zsh, tldr, antigen, profile-specific updates)
    if command -v task &> /dev/null; then
        task update
    else
        echo "$(tput setaf 1)Error: task not found. Run ./bootstrap.zsh to install.$(tput sgr0)"
        cd "$currentdir"
        return 1
    fi

    # Return to previous directory
    cd "$currentdir"
}
```

---

### Step 13: Update functionlist.zsh for Profile Awareness

**File**: `zsh/functions/functionlist.zsh`

**Issue**: Current implementation hardcodes `$DOTFILEDIR/zsh/functions/*` and won't show profile-specific functions.

**Replace entire content with**:

```bash
#!/bin/zsh

# List all custom functions defined in the dotfiles
function functionlist() {
    echo "$(tput setaf 6)Custom Functions:$(tput sgr0)"
    echo ""
    
    # Common functions (at zsh/functions/*.zsh level)
    echo "$(tput setaf 3)── Common ──$(tput sgr0)"
    for file in "$DOTFILEDIR/zsh/functions/"*.zsh(.N); do
        local funcname=$(basename "$file" .zsh)
        echo "  $funcname"
    done
    
    # Profile-specific functions (at zsh/functions/$profile/*.zsh)
    local profile="${DOTFILES_PROFILE:-}"
    if [[ -n "$profile" && -d "$DOTFILEDIR/zsh/functions/$profile" ]]; then
        echo ""
        echo "$(tput setaf 3)── Profile: $profile ──$(tput sgr0)"
        for file in "$DOTFILEDIR/zsh/functions/$profile/"*.zsh(.N); do
            local funcname=$(basename "$file" .zsh)
            echo "  $funcname"
        done
    fi
}
```

---

### Step 14: Update sshlist.zsh for Profile Awareness

**File**: `zsh/functions/sshlist.zsh`

**Issue**: Current implementation shows all SSH configs from all profiles, which may leak work host information on personal machines (or vice versa).

**Replace entire content with**:

```bash
#!/bin/zsh

# Display configured SSH host information for current profile only
function sshlist() {
    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""
    
    local profile="${DOTFILES_PROFILE:-personal}"
    
    # Main SSH config (always show)
    echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
    if [[ -f "$DOTFILEDIR/ssh/configs/config" ]]; then
        grep -E "^Host " "$DOTFILEDIR/ssh/configs/config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi
    
    # Profile-specific SSH config
    local profile_config="$DOTFILEDIR/ssh/configs/$profile/config_$profile"
    if [[ -f "$profile_config" ]]; then
        echo ""
        echo "$(tput setaf 3)── Profile: $profile ──$(tput sgr0)"
        grep -E "^Host " "$profile_config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi
    
    echo ""
    echo "$(tput setaf 8)Config files: ~/.ssh/config, ~/.ssh/config_$profile$(tput sgr0)"
}
```

---

### Step 15: Consider motd.zsh Placement

**File**: `zsh/functions/motd.zsh`

**Issue**: Contains personal branding ("JGRID", "TRON" theme) which may be inappropriate on work machines.

**Options** (choose one):

**Option A: Move to personal profile** (recommended):
```bash
# Move to zsh/functions/personal/motd.zsh
mv zsh/functions/motd.zsh zsh/functions/personal/motd.zsh
```

**Option B: Keep common but add profile guard**:
```bash
# Add at the beginning of the function:
function motd() {
    # Only show MOTD on personal profile
    if [[ "${DOTFILES_PROFILE:-personal}" != "personal" ]]; then
        return 0
    fi
    # ... rest of existing function
}
```

**Note**: If using Option A, also update `.zlogin` to check if `motd` function exists before calling it:

```bash
# In zsh/.zlogin, update motd call:
if (( $+functions[motd] )); then
    motd
fi
```

---

### Step 16: Add Antigen Guard to .zshrc

**File**: `zsh/.zshrc`

**Wrap the antigen loading section** (around line 54-67) with a guard:

```bash
# Load antigen for plugin management (with guard for partial installs)
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh"

    antigen use ohmyzsh/ohmyzsh
    antigen bundle ohmyzsh/ohmyzsh git
    antigen bundle ohmyzsh/ohmyzsh colorize
    antigen bundle ohmyzsh/ohmyzsh kubectl
    antigen bundle ohmyzsh/ohmyzsh plugins/extract
    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle zsh-users/zsh-completions
    antigen bundle zsh-users/zsh-autosuggestions
    antigen apply
else
    echo "$(tput setaf 3)Warning: antigen not found. Run './bootstrap.zsh' or 'task install' to complete setup.$(tput sgr0)"
fi
```

---

### Step 17: Create Profile Brewfiles

**File**: `install/personal/Brewfile.rb`

```ruby
# Personal-only Homebrew packages
# Add packages here that should only be on personal machines

# Example:
# cask "steam"
# cask "vlc"
```

**File**: `install/work/Brewfile.rb`

```ruby
# Work-only Homebrew packages
# Add packages here that should only be on work machines

# Example:
# cask "microsoft-teams"
# brew "awscli"
```

**Note**: These are in addition to the main `install/Brewfile.rb` which contains common packages for all profiles.

---

### Step 18: Add Deprecation Notice to install.zsh

**File**: `install.zsh`

**Add at the top after the shebang**:

```bash
#!/bin/zsh

echo "$(tput setaf 3)⚠ Warning: install.zsh is deprecated. Use ./bootstrap.zsh instead.$(tput sgr0)"
echo "Continuing with legacy install in 3 seconds..."
sleep 3

# ... rest of existing install.zsh
```

---

### Step 19: Update copilot-instructions.md

**File**: `.github/copilot-instructions.md`

Add section for Task-based workflow:

```markdown
### Task-Based Installation (New)

The dotfiles now use [go-task](https://taskfile.dev) for installation:

- Fresh install: `./bootstrap.zsh`
- Re-run install: `task install`
- Update everything: `task update` (or just `update` in shell)
- Show all tasks: `task --list`
- Set profile: `task profile:set PROFILE=personal`
- Validate install: `task validate`

Profile is stored at `${XDG_CONFIG_HOME}/dotfiles/profile`.
```

---

## Testing & Validation Checklist

Before considering the migration complete, verify each item:

### Bootstrap & Installation

- [ ] Fresh clone install: `git clone ... && cd dotfiles && ./bootstrap.zsh`
- [ ] Task is installed and in PATH after bootstrap
- [ ] Profile prompt appears on fresh install
- [ ] `task install` completes without errors
- [ ] XDG directories exist: `ls -la ~/.config ~/.local/share ~/.local/state ~/.cache`

### Profile System

- [ ] Profile persisted: `cat ~/.config/dotfiles/profile`
- [ ] `task profile:show` displays current profile
- [ ] `task profile:set PROFILE=work` changes profile
- [ ] `task profile:set PROFILE=invalid` fails with error

### Symlinks

- [ ] `ls -la ~/.zshenv` → points to dotfiles/zsh/.zshenv
- [ ] `ls -la ~/.config/git/config` → points to dotfiles/git/config
- [ ] Personal profile: `ls -la ~/.ssh/config_personal` exists
- [ ] Work profile: `ls -la ~/.ssh/config_work` exists (if configured)

### Shell Environment

- [ ] New zsh session loads without errors: `zsh -i -c 'exit'`
- [ ] `echo $DOTFILEDIR` resolves correctly
- [ ] `echo $DOTFILES_PROFILE` shows current profile
- [ ] `echo $HOMEBREW_PREFIX` set correctly (architecture-dependent)
- [ ] Antigen loads without warnings (check for "Warning:" in output)

### Functions & Aliases

- [ ] `functionlist` shows common AND profile-specific functions
- [ ] `sshlist` shows only current profile's SSH configs
- [ ] `update` command works (calls `task update`)
- [ ] Personal profile: `jgrid` alias available (from `zsh/aliases/personal/jgrid.zsh`)
- [ ] Work profile: `jgrid` alias NOT available
- [ ] Verify alias/function paths: `ls zsh/aliases/{common,personal,work}/`

### Update Flow

- [ ] `update` pulls latest changes
- [ ] `update` runs `task update` successfully
- [ ] oh-my-zsh updates (if applicable)
- [ ] tldr cache updates
- [ ] Antigen plugins update

### Graceful Degradation

- [ ] Shell loads if Task not installed (with warning)
- [ ] Shell loads if Antigen not installed (with warning)
- [ ] Shell loads if profile file missing (defaults to "personal")

### macOS Specifics (if applicable)

- [ ] `task install:macos` applies defaults without error
- [ ] Homebrew zsh available: `$HOMEBREW_PREFIX/bin/zsh --version`
- [ ] Xcode CLI tools installed: `xcode-select -p`

---

## Summary Checklist

| Step | File/Action | Purpose |
|------|-------------|---------|
| 0 | Create directories | Set up new directory structure |
| 1 | Create `bootstrap.zsh` | Entry point, installs Task |
| 2 | Create `Taskfile.yml` | Main task definitions |
| 3 | Create `taskfiles/common.yml` | XDG, ZDOTDIR |
| 4 | Create `taskfiles/profile.yml` | Profile management |
| 5 | Create `taskfiles/links.yml` | Symlinks with safe-link |
| 6 | Create `taskfiles/brew.yml` | Homebrew management |
| 7 | Create `taskfiles/macos.yml` | macOS defaults, xcode, shell |
| 8 | Create `taskfiles/personal.yml` | Personal profile |
| 9 | Create `taskfiles/work.yml` | Work profile |
| 10 | Restructure aliases | Move to zsh/aliases/{common,personal,work}/ |
| 11 | Update `.zshrc` | Profile-aware loading |
| 12 | Update `update.zsh` | Call task update |
| 13 | Update `functionlist.zsh` | Profile-aware function listing |
| 14 | Update `sshlist.zsh` | Profile-aware SSH config display |
| 15 | Consider `motd.zsh` placement | Personal-only or add guard |
| 16 | Add antigen guard | Graceful partial install |
| 17 | Create profile Brewfiles | Profile-specific packages |
| 18 | Deprecate `install.zsh` | Add warning |
| 19 | Update docs | copilot-instructions.md |

---

## Conclusion

This migration provides:

1. **Profile-aware installation** stored persistently at `${XDG_CONFIG_HOME}/dotfiles/profile`
2. **safe_link equivalent** via the `links:safe-link` internal task
3. **Bootstrap without Homebrew** using Task's official install script
4. **Maintained `update` command** that delegates to `task update`
5. **Graceful degradation** with guards for partial installs
6. **Runtime profile awareness** in `.zshrc` for aliases/functions
7. **Profile-aware utility functions** (`functionlist`, `sshlist`) that respect current profile
8. **Maintained top-level structure** (`docs`, `git`, `install`, `ssh`, `zsh`) with profile separation within subdirectories

### Directory Structure Principles

- **Top-level directories preserved**: `docs/`, `git/`, `install/`, `ssh/`, `zsh/`
- **Profile separation within directories**: `zsh/aliases/{common,personal,work}/`, `install/{personal,work}/`
- **Common files at top level when no separation needed**: `zsh/functions/*.zsh`, `zsh/configs/`, `zsh/styles/`
- **Profile subdirectories when separation needed**: `zsh/aliases/common/`, `zsh/aliases/personal/`, etc.

### Key Gotchas Summary

| Issue | Solution |
|-------|----------|
| Homebrew shellenv not inherited | Load explicitly in each task that needs it |
| Profile variable timing | Read at execution via shell, not parse time |
| Antigen/oh-my-zsh missing | Guards in `.zshrc` with warning messages |
| `functionlist.zsh` hardcoded paths | Updated to iterate common + profile directories |
| `sshlist.zsh` shows all profiles | Updated to only show current profile's configs |
| `motd.zsh` personal branding | Move to personal profile or add guard |
| `.zshrc` code duplication | Clear REMOVE/REPLACE instructions provided |

### SSH Config Note

The main `ssh/configs/config` file may need manual adjustment for profile-aware Include statements. This is intentionally left for manual configuration due to the security implications of SSH configs.
