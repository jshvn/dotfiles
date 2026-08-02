#!/usr/bin/env zsh

# =============================================================================
# install/tests/settings-compose.zsh -- smoke tests for compose-settings.zsh
#
# Purpose:      Exercise settings_compose_fragments + settings_preserved_keys
#               against throwaway fragment dirs: repo-fragment merge order,
#               state-dir fragments layering over repo fragments, missing and
#               empty state dirs, and preserved CLI-managed keys winning over
#               fragment values.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/compose-settings.zsh; install/messages.zsh; jq.
# Side effects: creates throwaway dirs under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:settings-compose)}"

source "${DOTFILEDIR}/install/messages.zsh"
source "${DOTFILEDIR}/install/compose-settings.zsh"

typeset -i failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

repo_d="${work}/settings.d"
state_d="${work}/state-settings.d"
mkdir -p "$repo_d" "$state_d"

echo '{"a": 1, "nested": {"x": 1}}' > "${repo_d}/00-base.json"
echo '{"b": 2, "nested": {"y": 2}}' > "${repo_d}/10-hooks.json"
echo '{"a": 9, "addon": true}'      > "${state_d}/99-addon-test.json"

# Scenario 1: repo fragments deep-merge in filename order; a missing state
# dir is tolerated.
out=$(settings_compose_fragments "$repo_d" "${work}/no-such-dir" '{}')
if [[ "$(echo "$out" | jq -c '{a, b, nested}')" == '{"a":1,"b":2,"nested":{"x":1,"y":2}}' ]]; then
  check "repo fragments deep-merge in filename order"
else
  cross "repo fragment merge wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 2: state-dir fragments layer after (over) repo fragments.
out=$(settings_compose_fragments "$repo_d" "$state_d" '{}')
if [[ "$(echo "$out" | jq -c '{a, addon}')" == '{"a":9,"addon":true}' ]]; then
  check "state-dir addon fragment overrides repo fragment"
else
  cross "state-dir layering wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 3: an existing-but-empty state dir composes like repo-only.
rm -f "${state_d}"/*.json
out=$(settings_compose_fragments "$repo_d" "$state_d" '{}')
if [[ "$(echo "$out" | jq -r '.a')" == "1" ]]; then
  check "empty state dir composes repo fragments only"
else
  cross "empty state dir handling wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 4: preserved keys layer over every fragment.
preserved='{"enabledPlugins": {"p": true}, "a": 42}'
out=$(settings_compose_fragments "$repo_d" "$state_d" "$preserved")
if [[ "$(echo "$out" | jq -c '{a, enabledPlugins}')" == '{"a":42,"enabledPlugins":{"p":true}}' ]]; then
  check "preserved keys layer over fragments"
else
  cross "preserved-key layering wrong: $out"
  failures=$(( failures + 1 ))
fi

# Scenario 5: settings_preserved_keys extracts only CLI-managed keys, and
# carries model/tui only when the live file has them.
live="${work}/settings.json"
echo '{"enabledPlugins": {"q": true}, "permissions": {}, "model": "opus", "tui": "fullscreen"}' > "$live"
out=$(settings_preserved_keys "$live")
if [[ "$(echo "$out" | jq -c 'keys | sort')" == '["enabledPlugins","extraKnownMarketplaces","model","tui"]' ]]; then
  check "settings_preserved_keys extracts CLI-managed keys only"
else
  cross "settings_preserved_keys wrong: $out"
  failures=$(( failures + 1 ))
fi

if (( failures == 0 )); then
  success "settings-compose: all scenarios passed"
else
  error "settings-compose: ${failures} scenario(s) failed"
fi
exit "$failures"
