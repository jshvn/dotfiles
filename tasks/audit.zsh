#!/bin/zsh

# =============================================================================
# tasks/audit.zsh -- drift the declaration cannot see: extra state and known CVEs
#
# Purpose:      validate asks "is everything declared present?"; this asks the
#               other direction: what is on the machine beyond the declaration
#               (packages brew would clean up, taps and trust grants nobody
#               declared, symlinks into the checkout nothing registered) and
#               which declared packages carry known vulnerabilities. Takes the
#               evaluated declaration on stdin (`task audit`). Findings are
#               warnings; exits 1 only with --strict.
# Depends on:   jq; brew (with the homebrew/brew-vulns tap); tasks/messages.zsh;
#               tasks/packages-trust-scan.zsh; tasks/links-audit-scan.zsh.
# Side effects: none (read-only; temp files for the Brewfile and scan inputs).
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"

strict=0
[[ "${1:-}" == --strict ]] && strict=1

declared=$(cat)
if ! jq -e '.dotfiles | type == "object"' <<< "$declared" >/dev/null 2>&1; then
  cross "no declaration on stdin (expected the JSON task audit produces with nix eval)"
  exit 1
fi
j() { jq -r "$1" <<< "$declared"; }
typeset -r CHECKOUT="$(j .dotfiles.checkout)"
drift=0

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
j .brewfile > "$tmpdir/Brewfile"

# --- packages installed beyond the declaration -------------------------------
info "packages beyond the declaration (brew bundle cleanup, dry run)"
# sections "Would uninstall formulae/casks/VSCode extensions:" and "Would untap:" list one item
# per line; the trailing "Would `brew cleanup`:" section is brew's own cache housekeeping, not drift
# stdout only: brew's own warnings (stale keg tabs, circular dependency notes) go to stderr
extra=$(brew bundle cleanup --file="$tmpdir/Brewfile" 2>/dev/null | awk '/^Would `brew cleanup`/ { exit } NF { print }' || true)
if [[ -z "$extra" ]]; then
  check "nothing installed beyond the declaration"
else
  while IFS= read -r line; do
    if [[ "$line" == Would* ]]; then
      info "  $line"
    else
      warn "drift: $line"
      drift=$((drift + 1))
    fi
  done <<< "$extra"
fi

# --- taps and trust grants nobody declared -----------------------------------
info "taps and trust"
j '.taps[].name' | sort -u > "$tmpdir/declared" # homebrew.taps is a list of records
brew tap 2>/dev/null | sort -u > "$tmpdir/installed" || true
brew trust --json v1 2>/dev/null > "$tmpdir/trust" || true
findings=$(zsh "$HERE/packages-trust-scan.zsh" "$tmpdir/declared" "$tmpdir/installed" "$tmpdir/trust")
if [[ -z "$findings" ]]; then
  check "every tap and trust grant is declared"
else
  while IFS= read -r line; do
    warn "drift: $line"
    drift=$((drift + 1))
  done <<< "$findings"
fi

# --- symlinks into the checkout that nothing registers -----------------------
info "orphan links"
orphans=$(j '.dotfiles.links | keys[]' | sed "s|^|$HOME/|" | zsh "$HERE/links-audit-scan.zsh" "$CHECKOUT" \
  "${XDG_CONFIG_HOME:-$HOME/.config}" "${ZDOTDIR:-$HOME/.config/zsh}" "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles" "$HOME/.ssh")
if [[ -z "$orphans" ]]; then
  check "no orphan links into the checkout"
else
  while IFS= read -r line; do
    warn "orphan: $line"
    drift=$((drift + 1))
  done <<< "$orphans"
fi

# --- known vulnerabilities in the declared set --------------------------------
info "brew vulns (severity >= high)"
vulns=$(brew vulns --brewfile="$tmpdir/Brewfile" --severity=high --json 2>/dev/null || true)
if ! jq -e '.findings | type == "array"' <<< "$vulns" >/dev/null 2>&1; then
  cross "brew vulns returned no parseable JSON (is the homebrew/brew-vulns tap installed?)"
  exit 1
fi
count=$(jq '.findings | length' <<< "$vulns")
if (( count == 0 )); then
  check "no findings"
else
  jq -r '.findings[] | "\(.package // .name // "?"): \(.id // "?") (\(.severity // "?"))"' <<< "$vulns" | while IFS= read -r line; do
    warn "vuln: $line"
  done
  drift=$((drift + count))
fi

if (( drift == 0 )); then
  success "audit: clean"
elif (( strict )); then
  error "audit: $drift finding(s)"
  exit 1
else
  warn "audit: $drift finding(s); --strict makes this exit 1"
fi
