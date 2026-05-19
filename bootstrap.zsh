#!/bin/zsh
# -----------------------------------------------------------------------------
# bootstrap.zsh -- acquire trust anchors (brew, go-task, yq) on a fresh macOS
# machine. Tools-only: does NOT take a machine name; does NOT invoke task setup.
#
# Sourced from: n/a (executed directly via ./bootstrap.zsh)
#
# Reads:        $DOTFILEDIR/install/messages.zsh
#               $DOTFILEDIR/manifests/machines/*.toml (for available-machines list)
#
# Writes:       nothing (no $XDG_STATE_HOME/dotfiles/* writes -- bootstrap is
#               tools-only per D-03; machine state is written by task setup)
#
# Depends on:   zsh (>= 5), curl, /bin/bash (for brew installer)
#
# Trust chain documented in docs/SECURITY.md (lands in Plan 02-06).
#
# After this script completes, the user runs:
#   task setup -- <machine-name>     # write machine state to XDG_STATE_HOME
#   task install                     # install dotfiles
#
# See docs/SECURITY.md for the trust-chain rationale (brew install script
# fetched via HTTPS from raw.githubusercontent.com/Homebrew/install; no
# checksum pin; go-task and yq installed via Homebrew-signed bottles).
# -----------------------------------------------------------------------------

set -euo pipefail

# --- DOTFILEDIR resolution (symlink-walk pattern, hardened for set -u)
# Uses BASH_SOURCE[0]:-$0 fallback so the variable is defined even in contexts
# where BASH_SOURCE is unavailable (e.g., plain zsh execution without bash
# compatibility). Port of the pattern from install/resolver.zsh and v1
# bootstrap.zsh, with the :-$0 guard added for set -u safety.
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR

# --- Source messages library
# messages.zsh handles its own set -u-safe double-source guard via the `:-`
# default expansion on $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u
# contract` block). A bare source is sufficient and idempotent.
source "${DOTFILEDIR}/install/messages.zsh"

header "Dotfiles v2 Bootstrap"

# --- Step 1: Homebrew acquisition (D-01)
# If brew is already present, skip the installer entirely -- sub-second no-op.
# If brew is absent, emit an AUDIT block to stderr with a 3-second abort window
# BEFORE fetching the installer script.  This surfaces the supply-chain trust
# boundary explicitly (HTTPS only, no checksum pin) so the user can ctrl-C.
if ! command -v brew >/dev/null 2>&1; then
  {
    echo
    echo "AUDIT: about to fetch and execute brew install script"
    echo "  source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    echo "  trust:  HTTPS only, no checksum pin (see docs/SECURITY.md)"
    echo "  ctrl-C now to abort (3 second window)"
    echo
  } >&2
  sleep 3
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

# --- Step 2: go-task acquisition (D-02)
# go-task is required before any `task` invocation.  Install via Homebrew --
# never via curl-pipe-to-shell (BTSP-02).
if ! command -v task >/dev/null 2>&1; then
  info "installing go-task..."
  brew install go-task
else
  info "go-task already installed: $(task --version)"
fi

# --- Step 3: yq acquisition with version floor (D-02, D-05)
# yq is required by install/resolver.zsh (deep-merge + TOML roundtrip).
# Minimum version: 4.52.1 (full TOML read/write; `. * .` deep-merge operator).
# A version older than 4.52.1 triggers a warning but does NOT abort --
# task setup will fail more obviously if yq is inadequate.
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

# --- Step 4: next-step hint (D-03)
# Bootstrap is tools-only: no task setup, no task install invocation.
# The user completes setup by running the two commands below.
echo
success "Bootstrap complete. Next steps:"
echo "  task setup -- <machine-name>     # write machine state"
echo "  task install                     # install dotfiles"
echo
machines=$(ls "${DOTFILEDIR}/manifests/machines"/*.toml 2>/dev/null \
  | xargs -n1 basename | sed 's/\.toml$//' | tr '\n' ' ')
echo "  Available machines: ${machines}"
