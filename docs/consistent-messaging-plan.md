# Consistent Messaging System for Dotfiles

## Overview

This document outlines a plan to implement a consistent messaging system across the dotfiles repository. The goal is to replace ad-hoc `echo` statements with standardized helper functions that provide consistent formatting, colorization, and semantic meaning.

## Current State Analysis

### Messaging Locations

The dotfiles have two distinct execution contexts:

1. **Zsh Scripts** (`install/*.zsh`, `bootstrap.zsh`)
   - Sourced or executed during installation
   - Use plain `echo` or `tput` for colorization
   - Examples:
     - `echo "Installing homebrew..."` (brew.zsh)
     - `echo "$(tput setaf 2)Dotfiles Bootstrap$(tput sgr0)"` (bootstrap.zsh)
     - `echo "Error: safe_link requires both source and target arguments"` (links.zsh)

2. **Taskfile YAML** (`Taskfile.yml`, `taskfiles/*.yml`)
   - Run via `task` command
   - Embed shell commands in YAML
   - Examples:
     - `echo "Installing Homebrew..."` (brew.yml)
     - `echo "$(tput setaf 2)Profile set to: ..."` (profile.yml)
     - `echo "✓ XDG config home exists"` (Taskfile.yml validate task)

### Current Inconsistencies

| Issue | Examples |
|-------|----------|
| No semantic distinction | `echo "Installing..."` vs `echo "Error: ..."` look the same |
| Inconsistent color usage | Some use `tput setaf`, others plain text |
| Verbose inline colorization | `$(tput setaf 2)text$(tput sgr0)` repeated everywhere |
| No visual hierarchy | Info, success, warnings all blend together |
| Validation task uses `✓`/`✗` | Different pattern than rest of codebase |

## Proposed Solution

### Target Functions

```zsh
# Color definitions (ANSI escape codes for portability)
DOTFILES_RED='\033[0;31m'
DOTFILES_GREEN='\033[0;32m'
DOTFILES_YELLOW='\033[0;33m'
DOTFILES_BLUE='\033[0;34m'
DOTFILES_NC='\033[0m'  # No Color

# Messaging functions
info()    { echo -e "${DOTFILES_BLUE}[INFO]${DOTFILES_NC} $*"; }
success() { echo -e "${DOTFILES_GREEN}[SUCCESS]${DOTFILES_NC} $*"; }
warn()    { echo -e "${DOTFILES_YELLOW}[WARN]${DOTFILES_NC} $*"; }
error()   { echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*"; }
```

### Alternative: tput-based (more portable, respects terminal capabilities)

```zsh
# Messaging functions using tput
info()    { echo "$(tput setaf 4)[INFO]$(tput sgr0) $*"; }
success() { echo "$(tput setaf 2)[SUCCESS]$(tput sgr0) $*"; }
warn()    { echo "$(tput setaf 3)[WARN]$(tput sgr0) $*"; }
error()   { echo "$(tput setaf 1)[ERROR]$(tput sgr0) $*"; }
```

## Implementation Options

### Option A: Shared Source File (Recommended)

Create a single source file that both zsh scripts and taskfiles can source.

**File Location**: `install/messages.zsh`

```zsh
#!/bin/zsh
# Dotfiles messaging library
# Source this file to get consistent messaging functions

# Prevent double-sourcing
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1

# Color codes (ANSI for broad compatibility)
DOTFILES_RED='\033[0;31m'
DOTFILES_GREEN='\033[0;32m'
DOTFILES_YELLOW='\033[0;33m'
DOTFILES_BLUE='\033[0;34m'
DOTFILES_CYAN='\033[0;36m'
DOTFILES_NC='\033[0m'

# Core messaging functions
info()    { echo -e "${DOTFILES_BLUE}[INFO]${DOTFILES_NC} $*"; }
success() { echo -e "${DOTFILES_GREEN}[SUCCESS]${DOTFILES_NC} $*"; }
warn()    { echo -e "${DOTFILES_YELLOW}[WARN]${DOTFILES_NC} $*"; }
error()   { echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2; }

# Extended messaging (optional)
debug()   { [[ "$DOTFILES_DEBUG" == "true" ]] && echo -e "${DOTFILES_CYAN}[DEBUG]${DOTFILES_NC} $*"; }
header()  { echo -e "\n${DOTFILES_GREEN}── $* ──${DOTFILES_NC}"; }
step()    { echo -e "${DOTFILES_BLUE}→${DOTFILES_NC} $*"; }
check()   { echo -e "${DOTFILES_GREEN}✓${DOTFILES_NC} $*"; }
cross()   { echo -e "${DOTFILES_RED}✗${DOTFILES_NC} $*"; }
```

**Usage in Zsh Scripts**:
```zsh
#!/bin/zsh
source "${DOTFILEDIR}/install/messages.zsh"

info "Installing homebrew..."
success "Homebrew installed"
error "Failed to install package"
```

**Usage in Taskfiles**:
```yaml
tasks:
  example:
    cmds:
      - |
        source "{{.DOTFILEDIR}}/install/messages.zsh"
        info "Starting task..."
        success "Task complete"
```

### Option B: Inline Function Definitions in Taskfile

Define functions directly in `Taskfile.yml` as a reusable task.

```yaml
vars:
  MSG_FUNCTIONS: |
    info()    { echo -e "\033[0;34m[INFO]\033[0m $*"; }
    success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
    warn()    { echo -e "\033[0;33m[WARN]\033[0m $*"; }
    error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

tasks:
  example:
    cmds:
      - |
        {{.MSG_FUNCTIONS}}
        info "Starting task..."
```

### Option C: Hybrid Approach

- Use Option A for zsh scripts (cleaner, proper sourcing)
- Use Option B inline vars for taskfiles (avoids source path issues)

## Detailed Implementation Plan (Option A - Recommended)

### Phase 1: Create Messaging Library

**Create file**: `install/messages.zsh`

```zsh
#!/bin/zsh
# Dotfiles messaging library
# Source this file to get consistent messaging functions
#
# Usage:
#   source "${DOTFILEDIR}/install/messages.zsh"
#   info "This is an info message"
#   success "Operation completed"
#   warn "This might cause issues"
#   error "Something went wrong"
#
# Optional functions:
#   debug "Debug output" (only shown if DOTFILES_DEBUG=true)
#   header "Section Name" (prints a styled section header)
#   step "Doing something" (prints a step indicator)
#   check "Item passed" (prints ✓ with message)
#   cross "Item failed" (prints ✗ with message)

# Prevent double-sourcing
[[ -n "$DOTFILES_MESSAGES_LOADED" ]] && return 0
DOTFILES_MESSAGES_LOADED=1

# Color codes (ANSI for broad compatibility)
# Using \033 instead of \e for maximum portability
DOTFILES_RED='\033[0;31m'
DOTFILES_GREEN='\033[0;32m'
DOTFILES_YELLOW='\033[0;33m'
DOTFILES_BLUE='\033[0;34m'
DOTFILES_CYAN='\033[0;36m'
DOTFILES_BOLD='\033[1m'
DOTFILES_NC='\033[0m'

# Core messaging functions
function info() {
    echo -e "${DOTFILES_BLUE}[INFO]${DOTFILES_NC} $*"
}

function success() {
    echo -e "${DOTFILES_GREEN}[SUCCESS]${DOTFILES_NC} $*"
}

function warn() {
    echo -e "${DOTFILES_YELLOW}[WARN]${DOTFILES_NC} $*"
}

function error() {
    echo -e "${DOTFILES_RED}[ERROR]${DOTFILES_NC} $*" >&2
}

# Extended messaging functions
function debug() {
    [[ "$DOTFILES_DEBUG" == "true" ]] && echo -e "${DOTFILES_CYAN}[DEBUG]${DOTFILES_NC} $*"
}

function header() {
    echo ""
    echo -e "${DOTFILES_GREEN}${DOTFILES_BOLD}── $* ──${DOTFILES_NC}"
}

function step() {
    echo -e "${DOTFILES_BLUE}→${DOTFILES_NC} $*"
}

function check() {
    echo -e "${DOTFILES_GREEN}✓${DOTFILES_NC} $*"
}

function cross() {
    echo -e "${DOTFILES_RED}✗${DOTFILES_NC} $*"
}
```

### Phase 2: Update Install Scripts

**Files to update**:

| File | Current Messages | Change To |
|------|------------------|-----------|
| `bootstrap.zsh` | `echo "$(tput setaf 2)Dotfiles Bootstrap$(tput sgr0)"` | `header "Dotfiles Bootstrap"` |
| `bootstrap.zsh` | `echo "Installing go-task..."` | `info "Installing go-task..."` |
| `bootstrap.zsh` | `echo "go-task installed to $INSTALL_DIR"` | `success "go-task installed to $INSTALL_DIR"` |
| `install/brew.zsh` | `echo "Installing homebrew..."` | `info "Installing Homebrew..."` |
| `install/brew.zsh` | `echo "Updating homebrew..."` | `info "Updating Homebrew..."` |
| `install/brew.zsh` | `echo "Installing all packages..."` | `info "Installing packages from Brewfile..."` |
| `install/links.zsh` | `echo "Error: safe_link requires..."` | `error "safe_link requires both source and target arguments"` |
| `install/links.zsh` | `echo "Setting up symbolic links..."` | `info "Setting up symbolic links..."` |
| `install/defaults.zsh` | `echo "We're setting our defaults..."` | `info "Applying macOS defaults..."` |
| `install/defaults.zsh` | `echo "All done! Some of the defaults..."` | `success "Defaults applied. Some changes require logout/restart."` |
| `install/xcode.zsh` | `echo "Xcode Command Line Tools already installed..."` | `success "Xcode Command Line Tools already installed"` |
| `install/xcode.zsh` | `echo "Installing Xcode Command Line Tools"` | `info "Installing Xcode Command Line Tools..."` |
| `install/xdg.zsh` | `echo "Ensuring XDG Base Directories exist..."` | `info "Ensuring XDG Base Directories exist..."` |
| `install/xdg.zsh` | `echo "XDG Base Directories setup!"` | `success "XDG Base Directories created"` |
| `install/zdotdir.zsh` | `echo "Creating $etc_zshenv..."` | `info "Creating $etc_zshenv with ZDOTDIR export..."` |
| `install/setshell.zsh` | `echo "Homebrew-installed ZSH is not..."` | `info "Adding Homebrew zsh to /etc/shells..."` |

**Example transformation for `install/brew.zsh`**:

Before:
```zsh
#!/bin/zsh

# install homebrew
echo "Installing homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # ... rest of script
fi

echo "Updating homebrew..."
brew update
brew upgrade

echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb
```

After:
```zsh
#!/bin/zsh
source "${DOTFILEDIR}/install/messages.zsh"

info "Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # ... rest of script
    success "Homebrew installed"
else
    info "Homebrew already installed"
fi

info "Updating Homebrew..."
brew update
brew upgrade
success "Homebrew updated"

info "Installing packages from Brewfile..."
brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb
success "Brewfile packages installed"
```

### Phase 3: Update Taskfiles

**Files to update**:

| File | Tasks Affected |
|------|----------------|
| `taskfiles/common.yml` | `xdg`, `zdotdir`, `antigen-update` |
| `taskfiles/profile.yml` | `ensure`, `set`, `show`, `install` |
| `taskfiles/brew.yml` | `install`, `bundle` |
| `taskfiles/macos.yml` | `xcode`, `shell` |
| `taskfiles/personal.yml` | `install` |
| `taskfiles/work.yml` | `install` |
| `Taskfile.yml` | `install`, `validate`, `clean` |

**Pattern for taskfile updates**:

Before:
```yaml
tasks:
  install:
    cmds:
      - |
        if ! command -v brew &> /dev/null; then
          echo "Installing Homebrew..."
          # ...
        else
          echo "Homebrew already installed"
        fi
```

After:
```yaml
tasks:
  install:
    cmds:
      - |
        source "{{.DOTFILEDIR}}/install/messages.zsh"
        if ! command -v brew &> /dev/null; then
          info "Installing Homebrew..."
          # ...
          success "Homebrew installed"
        else
          info "Homebrew already installed"
        fi
```

**Special case: Validate task in Taskfile.yml**:

Before:
```yaml
validate:
  cmds:
    - test -d {{.XDG_CONFIG_HOME}} && echo "✓ XDG config home exists" || echo "✗ XDG config home missing"
```

After:
```yaml
validate:
  cmds:
    - |
      source "{{.DOTFILEDIR}}/install/messages.zsh"
      test -d "{{.XDG_CONFIG_HOME}}" && check "XDG config home exists" || cross "XDG config home missing"
```

### Phase 4: Update Bootstrap

**File**: `bootstrap.zsh`

The bootstrap file is special because it runs before `DOTFILEDIR` might be reliably set. It should compute the path first, then source the messages library.

Before:
```zsh
#!/bin/zsh
set -e

echo "$(tput setaf 2)Dotfiles Bootstrap$(tput sgr0)"
echo ""

# Resolve DOTFILEDIR
SOURCE="${BASH_SOURCE[0]:-$0}"
# ... resolution logic ...
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# Install go-task if not present
if ! command -v task &> /dev/null; then
  echo "Installing go-task..."
  # ...
  echo "go-task installed to $INSTALL_DIR"
fi
```

After:
```zsh
#!/bin/zsh
set -e

# Resolve DOTFILEDIR first (needed for sourcing messages)
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# Source messaging library
source "${DOTFILEDIR}/install/messages.zsh"

header "Dotfiles Bootstrap"

# Install go-task if not present
if ! command -v task &> /dev/null; then
  info "Installing go-task..."
  # ...
  success "go-task installed to $INSTALL_DIR"
else
  info "go-task already installed"
fi

# Run task install
cd "$DOTFILEDIR"
task install "$@"
```

## Pros and Cons

### Pros

| Benefit | Description |
|---------|-------------|
| **Consistency** | All messages look the same across the entire installation |
| **Semantic clarity** | Easy to distinguish info, success, warnings, and errors at a glance |
| **Maintainability** | Change colors/format in one place, applies everywhere |
| **Debugging** | `DOTFILES_DEBUG=true` enables verbose output without code changes |
| **Readability** | Code becomes self-documenting (`success "Done"` vs `echo "$(tput setaf 2)Done$(tput sgr0)"`) |
| **Error handling** | `error()` outputs to stderr automatically |
| **Professional appearance** | Consistent branding across all installation output |
| **Extensible** | Easy to add new message types (`notice()`, `fatal()`, etc.) |

### Cons

| Drawback | Mitigation |
|----------|------------|
| **Extra source line needed** | One line per file; could add to a common include |
| **DOTFILEDIR dependency** | Bootstrap must resolve path before sourcing |
| **Potential namespace collision** | Functions prefixed behavior or wrapped (unlikely for common names like `info`) |
| **Slight overhead** | Negligible; one file read per script |
| **Migration effort** | One-time cost; can be done incrementally |
| **Taskfile verbosity** | Each multi-line cmd block needs source line |

## Testing Plan

1. **Create the library file** and verify it sources without errors:
   ```zsh
   source install/messages.zsh
   info "Test info"
   success "Test success"
   warn "Test warn"
   error "Test error"
   ```

2. **Migrate one script** (e.g., `install/brew.zsh`) and run it manually

3. **Run full installation** via `task install` on a test profile

4. **Verify colors** in terminal:
   - INFO should be blue
   - SUCCESS should be green
   - WARN should be yellow
   - ERROR should be red (and go to stderr)

5. **Test validation task** to ensure check/cross display correctly

## File Manifest

Files to **create**:
- `install/messages.zsh` - Messaging library

Files to **modify**:
- `bootstrap.zsh`
- `install/brew.zsh`
- `install/defaults.zsh`
- `install/links.zsh`
- `install/setshell.zsh`
- `install/xcode.zsh`
- `install/xdg.zsh`
- `install/zdotdir.zsh`
- `Taskfile.yml`
- `taskfiles/common.yml`
- `taskfiles/profile.yml`
- `taskfiles/brew.yml`
- `taskfiles/macos.yml`
- `taskfiles/personal.yml`
- `taskfiles/work.yml`

## Summary

Implementing a consistent messaging system requires:

1. Creating `install/messages.zsh` with standardized functions
2. Adding `source "${DOTFILEDIR}/install/messages.zsh"` to each zsh script
3. Replacing `echo` statements with appropriate semantic function calls
4. Testing the full installation flow

The total effort is approximately:
- 1 new file (~70 lines)
- ~15 files to modify
- ~80 echo statements to replace

This is a one-time investment that will improve maintainability and user experience for all future development.
