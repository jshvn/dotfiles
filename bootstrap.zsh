#!/bin/zsh

# =============================================================================
# bootstrap.zsh -- bring a Mac from nothing to its declared state
#
# Purpose:      ./bootstrap.zsh <machine>: install Homebrew, go-task and Nix
#               (each skipped when present), select the machine (`task setup`)
#               and run the first `task install`, which builds and switches.
#               Safe to re-run; afterwards `task install` is the only command.
#               The machine is named explicitly, never inferred from the
#               hostname.
# Depends on:   zsh (>= 5), curl, /bin/bash (the brew installer), sh (the
#               Nix installer), sudo (the Nix installer and the switch);
#               tasks/messages.zsh; machines/<machine>.nix; Taskfile.yml;
#               docs/SECURITY.md (the trust chain).
# Side effects: installs Homebrew (HTTPS-fetched script, no checksum pin);
#               brew-installs go-task; runs the official multi-user Nix
#               installer (HTTPS-fetched to a temp file, no checksum pin):
#               creates the /nix volume, the build users and the nix-daemon
#               launchd job, prepends a Nix block to /etc/zshrc and
#               /etc/bashrc with .backup-before-nix copies; then everything
#               `task setup` and `task install` do.
# =============================================================================

set -euo pipefail

DOTFILEDIR="${0:A:h}"
export DOTFILEDIR

source "${DOTFILEDIR}/tasks/messages.zsh"

machines=( "${DOTFILEDIR}/machines"/*.nix(N:t:r) )
machine="${1:-}"
if [[ -z "$machine" || ! -f "${DOTFILEDIR}/machines/${machine}.nix" ]]; then
  error "usage: ./bootstrap.zsh <machine>   (the machines: ${machines[*]})"
  exit 1
fi

header "Dotfiles v3 Bootstrap: $machine"

# consent WHAT SOURCE TRUST-NOTE: print the AUDIT block, require Enter from the tty
consent() {
  {
    echo
    echo "AUDIT: about to execute $1"
    echo "  source: $2"
    echo "  trust:  $3 (see docs/SECURITY.md)"
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
}

# Step 1: Homebrew.
if ! command -v brew >/dev/null 2>&1; then
  consent "the brew install script" "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "HTTPS only, no checksum pin"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)" # lint-allow: hardcoded-prefix
  else
    eval "$(/usr/local/bin/brew shellenv)" # lint-allow: hardcoded-prefix
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

# Step 3: Nix, the official multi-user installer. Downloaded to a file first so it can be read
# before it runs; --daemon is the multi-user install, --yes answers its questions (sudo still
# asks for the password).
if [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
  info "nix already installed: $(/nix/var/nix/profiles/default/bin/nix --version)"
else
  installer=$(mktemp "${TMPDIR:-/tmp}/nix-install.XXXXXX")
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://nixos.org/nix/install -o "$installer"
  consent "the Nix multi-user installer, saved at $installer (read it first: less $installer)" \
    "https://nixos.org/nix/install" "HTTPS only, no checksum pin; sudo; edits /etc/zshrc and /etc/bashrc"
  sh "$installer" --daemon --yes
fi

# Step 4: select the machine and converge it. task calls nix by its absolute path, so this works
# in the same shell that just installed Nix.
task -d "$DOTFILEDIR" setup -- "$machine"
task -d "$DOTFILEDIR" install

echo
success "Bootstrap complete: open a new terminal. From now on, update (task install) is the only command."
