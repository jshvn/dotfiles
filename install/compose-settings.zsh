#!/bin/zsh

# =============================================================================
# install/compose-settings.zsh -- shared claude/settings.json compose helpers
#
# Purpose:      Single source of truth for the two pieces of the settings
#               compose algorithm that claude:settings-compose AND claude:audit
#               both need: the preserved-CLI-keys jq expression and the
#               fragment deep-merge. Keeping one copy removes the alignment
#               hazard the two task bodies used to warn about.
# Depends on:   jq (same as claude.yml).
# Side effects: none -- defines settings_preserved_keys /
#               settings_compose_fragments; both are read-only and print to
#               stdout (callers redirect/capture).
# =============================================================================

# Sourced into go-task's shell (NOT executed): no `set -euo pipefail` here --
# it would mutate the caller's shell options. Source this BEFORE the caller's
# own `set -euo pipefail`, mirroring install/messages.zsh.
[[ -n "${DOTFILES_COMPOSE_SETTINGS_LOADED:-}" ]] && return 0
DOTFILES_COMPOSE_SETTINGS_LOADED=1

# settings_preserved_keys <settings_json>
# Echo the CLI-managed keys to carry across a recompose: enabledPlugins and
# extraKnownMarketplaces (written by `claude plugin ...`), plus model (written
# by the /model command) ONLY when present so an absent key never becomes null.
# When the file does not exist yet, echo the empty defaults.
settings_preserved_keys() {
  local target="$1"
  if [[ -f "$target" ]]; then
    jq -c '{enabledPlugins: (.enabledPlugins // {}), extraKnownMarketplaces: (.extraKnownMarketplaces // {})} + (if has("model") then {model} else {} end)' "$target"
  else
    printf '%s\n' '{"enabledPlugins": {}, "extraKnownMarketplaces": {}}'
  fi
}

# settings_compose_fragments <settings_d> <preserved_json> [jq_flag]
# Deep-merge every *.json fragment under <settings_d> in filename (argv) order
# -- numeric prefix = merge priority -- then layer the preserved keys on top.
# Pass `-S` as the optional 3rd arg to sort keys (claude:audit uses this to
# normalize key order for its diff; the compose path passes nothing so the
# written settings.json byte-matches the historical output). Output to stdout.
settings_compose_fragments() {
  local settings_d="$1" preserved="$2" flag="${3:-}"
  jq -s $flag --argjson preserved "$preserved" \
    'reduce .[] as $f ({}; . * $f) | . * $preserved' \
    "$settings_d"/*.json
}
