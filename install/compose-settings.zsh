#!/bin/zsh

# =============================================================================
# install/compose-settings.zsh -- shared settings.json compose helpers
#
# Purpose:      Single source of truth for the two pieces of the settings
#               compose algorithm that claude:settings-compose AND claude:audit
#               both need: the preserved-CLI-keys jq expression and the
#               deep-merge of the two fragment sources (repo
#               claude/settings.d/ + machine $XDG_STATE_HOME/dotfiles/
#               settings.d/). Keeping one copy removes the alignment hazard
#               the two task bodies used to warn about.
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
# by the /model command) and tui (written by the fullscreen/inline TUI toggle)
# ONLY when present so an absent key never becomes null. When the file does not
# exist yet, echo the empty defaults.
settings_preserved_keys() {
  local target="$1"
  if [[ -f "$target" ]]; then
    jq -c '{enabledPlugins: (.enabledPlugins // {}), extraKnownMarketplaces: (.extraKnownMarketplaces // {})} + (if has("model") then {model} else {} end) + (if has("tui") then {tui} else {} end)' "$target"
  else
    printf '%s\n' '{"enabledPlugins": {}, "extraKnownMarketplaces": {}}'
  fi
}

# settings_compose_fragments <repo_settings_d> <state_settings_d> <preserved_json> [jq_flag]
# Deep-merge every *.json fragment: repo dir first (numeric filename prefix =
# merge priority), then the state dir (machine-generated addon fragments,
# 99-addon-* by convention), then layer the preserved keys on top. The state
# dir may be missing or empty -- a machine with no addons never creates it.
# Pass `-S` as the optional 4th arg to sort keys (drift comparisons use this to
# normalize key order). Output to stdout. find (not a glob) enumerates
# fragments: portable across zsh and go-task's embedded shell, and immune to
# zsh's nomatch abort on an empty dir.
settings_compose_fragments() {
  local repo_d="$1" state_d="$2" preserved="$3" flag="${4:-}"
  {
    find "$repo_d" -maxdepth 1 -name '*.json' 2>/dev/null | sort
    if [ -d "$state_d" ]; then
      find "$state_d" -maxdepth 1 -name '*.json' 2>/dev/null | sort
    fi
  } | while IFS= read -r f; do
    cat "$f"
  done | jq -s $flag --argjson preserved "$preserved" \
    'reduce .[] as $f ({}; . * $f) | . * $preserved'
}
