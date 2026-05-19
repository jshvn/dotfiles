#!/bin/zsh

# =============================================================================
# bootstrap.zsh -- acquire trust anchors on a fresh macOS machine
#
# Purpose:      Install brew, go-task, and yq -- the three tools required
#               before any `task` invocation. Tools-only: does NOT take a
#               machine name and does NOT invoke `task setup`.
# Depends on:   zsh (>= 5), curl, /bin/bash (for the brew installer);
#               install/messages.zsh; docs/SECURITY.md (trust chain doc).
# Side effects: installs Homebrew (HTTPS-fetched script, no checksum pin);
#               brew-installs go-task + yq; warns if installed yq < 4.52.1.
# =============================================================================

set -euo pipefail

# DOTFILEDIR resolution (symlink-walk pattern). BASH_SOURCE[0]:-$0 fallback
# ensures the variable is defined even in contexts where BASH_SOURCE is
# unavailable (plain zsh execution without bash compatibility).
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
source "${DOTFILEDIR}/install/messages.zsh"

header "Dotfiles v2 Bootstrap"

# Step 1: Homebrew. If brew is absent, emit an AUDIT block to stderr and
# require an explicit Enter keypress BEFORE fetching the installer script
# -- surfaces the supply-chain trust boundary (HTTPS, no checksum pin) so
# the user must consciously consent (any other key aborts).
if ! command -v brew >/dev/null 2>&1; then
  {
    echo
    echo "AUDIT: about to fetch and execute brew install script"
    echo "  source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    echo "  trust:  HTTPS only, no checksum pin (see docs/SECURITY.md)"
    echo
    echo "  Press Enter to continue. Any other key aborts."
    echo
  } >&2
  read -rs -k 1 reply </dev/tty
  echo >&2
  if [[ "$reply" != $'\n' && "$reply" != $'\r' ]]; then
    error "aborted by user"
    exit 1
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Re-shellenv so brew is on PATH for the rest of this script.
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  info "brew already installed: $(brew --version | head -1)"
fi

# Step 2: go-task via Homebrew -- never via curl-pipe-to-shell.
if ! command -v task >/dev/null 2>&1; then
  info "installing go-task..."
  brew install go-task
else
  info "go-task already installed: $(task --version)"
fi

# Step 3: yq. Minimum version 4.52.1 (full TOML read/write; `. * .`
# deep-merge operator). Older versions trigger a warning but do NOT abort
# -- `task setup` will fail more obviously if yq is inadequate.
if ! command -v yq >/dev/null 2>&1; then
  info "installing yq..."
  brew install yq
else
  yq_ver=$(yq --version | sed -nE 's/.*version v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
  info "yq already installed: v${yq_ver}"
  if ! printf '%s\n%s\n' "4.52.1" "$yq_ver" | sort -V -C 2>/dev/null; then
    warn "yq v${yq_ver} is older than minimum 4.52.1 -- upgrade with: brew upgrade yq"
  fi
fi

# Tools-only: no task setup, no task install invocation. The user
# completes setup by running the two commands below.
echo
success "Bootstrap complete. Next steps:"
echo "  task setup -- <machine-name>     # write machine state"
echo "  task install                     # install dotfiles"
echo
machines=$(ls "${DOTFILEDIR}/manifests/machines"/*.toml 2>/dev/null \
  | xargs -n1 basename | sed 's/\.toml$//' | tr '\n' ' ')
echo "  Available machines: ${machines}"
