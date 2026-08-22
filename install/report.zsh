#!/usr/bin/env zsh

# =============================================================================
# install/report.zsh -- converged-install overview in markdown
#
# Purpose:      Print one markdown summary of the installed system: machine
#               identity, feature flags, declared-vs-installed package counts
#               per manager, symlinks, Claude settings, and shell plumbing.
#               Consumed by `task report` at a prompt and by CI, which writes
#               it to the job summary so a run can be read at a glance later.
# Depends on:   jq; $XDG_STATE_HOME/dotfiles/{machine,resolved.json,build/}.
#               Per-manager installed counts probe the manager CLI when it is
#               on PATH (brew, mas, code, cargo, uv, npm) and print `-` when
#               it is not, so the report never fails on a machine lacking one.
# Side effects: none. Writes markdown to stdout only.
# =============================================================================

set -euo pipefail
setopt null_glob

typeset -r DOTFILEDIR="${DOTFILEDIR:?DOTFILEDIR must be set}"
typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r RESOLVED="${STATE_DIR}/resolved.json"
typeset -r BUILD="${STATE_DIR}/build"

if [[ ! -s "$RESOLVED" ]]; then
  print -u2 "report: ${RESOLVED} missing; run: task setup -- <machine-name>"
  exit 1
fi

# count <text>: number of non-empty lines. `-` when the probe is unavailable.
count() { [[ -z "$1" ]] && print 0 || print -r -- "$1" | ggrep -c . || true; }
has() { command -v "$1" >/dev/null 2>&1; }

# ---- installed-count probes ------------------------------------------------
# Naming contract: installed_<manager>_<kind> for each `.packages.<manager>
# .<kind>` array in resolved.json. The table loop below looks the function up
# by name; a manager the resolver adds later appears with its declared count
# immediately and shows `-` for installed until a probe is written here.
installed_brew_formulae() {
  has brew || return 1
  print -r -- "$(brew leaves 2>/dev/null | ggrep -c . || true) leaves / $(brew list --formula 2>/dev/null | ggrep -c . || true) total"
}
installed_brew_casks()    { has brew || return 1; brew list --cask 2>/dev/null | ggrep -c . || true; }
installed_brew_mas()      { has mas  || return 1; mas list 2>/dev/null | ggrep -c . || true; }
installed_vscode_extensions() { has code || return 1; code --list-extensions 2>/dev/null | ggrep -c . || true; }
installed_cargo_crates()  { has cargo || return 1; cargo install --list 2>/dev/null | awk '/^[^[:space:]].*:$/' | ggrep -c . || true; }
installed_uv_tools()      { has uv || return 1; uv tool list 2>/dev/null | awk '/^[A-Za-z0-9._-]+ v[0-9]/' | ggrep -c . || true; }
installed_npm_packages()  {
  has npm || return 1
  npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | keys[]' | ggrep -vxE 'npm|corepack' | ggrep -c . || true
}

# ---- header ----------------------------------------------------------------
machine=$(head -n1 "${STATE_DIR}/machine" 2>/dev/null || print unknown)
sha=$(git -C "$DOTFILEDIR" rev-parse --short HEAD 2>/dev/null || print unknown)
print "## Dotfiles install report"
print
print "| | |"
print "|---|---|"
print "| Machine | \`${machine}\` -- $(jq -r '.meta.description' "$RESOLVED") |"
print "| Platform | $(jq -r '"\(.platform.os)/\(.platform.arch)"' "$RESOLVED") on $(sw_vers -productVersion 2>/dev/null || uname -r) |"
print "| Commit | \`${sha}\` |"
print "| Generated | $(date -u '+%Y-%m-%d %H:%M UTC') |"
print "| Toolchain | zsh ${ZSH_VERSION}, $(has brew && brew --version | head -n1 || print 'brew absent'), task $(task --version 2>/dev/null | awk '{print $NF}') |"
print

# ---- features --------------------------------------------------------------
enabled=$(jq -r '.features | to_entries | map(select(.value)) | .[].key' "$RESOLVED")
disabled=$(jq -r '.features | to_entries | map(select(.value | not)) | .[].key' "$RESOLVED")
print "## Features: $(count "$enabled") enabled, $(count "$disabled") disabled"
print
print "Enabled: $(print -r -- "$enabled" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')"
print

# ---- packages --------------------------------------------------------------
print "## Packages"
print
print "| Manager | Kind | Declared | Installed |"
print "|---|---|---:|---:|"
jq -r '.packages | to_entries[] | .key as $m | .value | to_entries[] | "\($m)\t\(.key)\t\(.value | length)"' "$RESOLVED" \
| while IFS=$'\t' read -r mgr kind declared; do
    fn="installed_${mgr}_${kind}"
    installed='-'
    if (( $+functions[$fn] )); then installed=$("$fn" || print -- '-'); fi
    print "| ${mgr} | ${kind} | ${declared} | ${installed} |"
  done
print

# ---- links -----------------------------------------------------------------
if [[ -s "${BUILD}/links.map" ]]; then
  total=0 live=0
  while IFS=$'\t' read -r target source; do
    [[ -z "$target" ]] && continue
    total=$(( total + 1 ))
    [[ -L "$target" && "$(readlink "$target")" == "$source" ]] && live=$(( live + 1 ))
  done < "${BUILD}/links.map"
  print "## Links: ${live}/${total} converged"
else
  print "## Links: build/links.map not written"
fi
print

# ---- claude ----------------------------------------------------------------
addons=$(jq -r '.claude.addons[]?' "$RESOLVED")
# The addon script owns the installed-ness rule ([verify].path/command);
# count its "yes yes" (enabled, installed) rows rather than re-deriving it.
addon_installed=$(zsh "${DOTFILEDIR}/install/claude-addons.zsh" list 2>/dev/null \
  | awk '$2=="yes" && $3=="yes"' | ggrep -c . || true)
fragments=$(count "$(ls "${DOTFILEDIR}/claude/settings.d/"*.json "${STATE_DIR}/settings.d/"*.json 2>/dev/null || true)")
hooks='-'
[[ -s "${BUILD}/settings.json" ]] && hooks=$(jq '[.hooks // {} | .[] | .[] | .hooks[]?] | length' "${BUILD}/settings.json")
print "## Claude"
print
print -- "- settings.json composed from ${fragments} fragment(s), ${hooks} hook command(s)"
print -- "- addons: ${addon_installed}/$(count "$addons") declared addons installed"
print

# ---- shell -----------------------------------------------------------------
plugins=$(ggrep -cvE '^\s*(#|$)' "${DOTFILEDIR}/shell/.zsh_plugins.txt" 2>/dev/null || true)
print "## Shell"
print
print -- "- ${plugins:-0} antidote bundles, $(ls "${DOTFILEDIR}"/shell/aliases/*.zsh 2>/dev/null | ggrep -c . || true) alias files, $(ls "${DOTFILEDIR}"/shell/functions/*.zsh 2>/dev/null | ggrep -c . || true) functions"
print -- "- login shell: \`${SHELL:-?}\`"
