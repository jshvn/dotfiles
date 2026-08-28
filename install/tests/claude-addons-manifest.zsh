#!/usr/bin/env zsh

# =============================================================================
# install/tests/claude-addons-manifest.zsh -- smoke tests for the addon TOMLs
#
# Purpose:      Enforce the contract install/claude-addons.zsh relies on when
#               it evals addon commands: every command in [install],
#               [upgrade], [remove] and [verify] parses as zsh and occupies
#               exactly one line. Plus the ecc invariant that its payload
#               selection reads the same after the marketplace line in both
#               [install] and [upgrade].
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/messages.zsh; yq.
# Side effects: none; reads manifests/claude-addons/*.toml.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:claude-addons-manifest)}"

source "${DOTFILEDIR}/install/messages.zsh"

typeset -i failures=0
addons_dir="${DOTFILEDIR}/manifests/claude-addons"

# Parses a command without running it: eval reads the function body and
# stops there, so a syntax error fails while a command substitution never
# runs. Same operator-owned trust boundary as the evals in
# install/claude-addons.zsh -- these TOMLs are repo-owned.
parse_ok() {
  eval "_probe_cmd() {
$1
}" 2>/dev/null
}

for toml in "$addons_dir"/*.toml(N); do
  name="${toml:t:r}"
  typeset -i before=$failures

  for key in install upgrade remove; do
    yq -e -o=json ".${key}.commands" "$toml" >/dev/null 2>&1 || continue

    # A command carrying an embedded newline is read as two commands by the
    # line-based eval loop, which drops any shell state the first line set up.
    count=$(yq -o=json ".${key}.commands | length" "$toml")
    lines=$(yq -r ".${key}.commands[]" "$toml" | wc -l | tr -d ' ')
    if [[ "$count" != "$lines" ]]; then
      cross "${name} [${key}]: ${count} commands span ${lines} lines (one line each)"
      failures=$(( failures + 1 ))
    fi

    while IFS= read -r cmd; do
      [[ -z "$cmd" ]] && continue
      if ! parse_ok "$cmd"; then
        cross "${name} [${key}]: command does not parse: ${cmd[1,60]}"
        failures=$(( failures + 1 ))
      fi
    done < <(yq -r ".${key}.commands[]" "$toml")
  done

  if yq -e -o=json '.verify.command' "$toml" >/dev/null 2>&1; then
    verify=$(yq -r '.verify.command' "$toml")
    if ! parse_ok "$verify"; then
      cross "${name} [verify]: command does not parse"
      failures=$(( failures + 1 ))
    fi
  fi

  if (( failures == before )); then
    check "${name}: commands parse and are single-line"
  fi
done

# ecc names its payload selection twice: [install] runs it after the
# marketplace add, [upgrade] after the marketplace update. Editing one and
# not the other changes only fresh installs -- a converged machine runs
# [upgrade] -- so the divergence would stay invisible until a new machine.
ecc_toml="${addons_dir}/ecc.toml"
if [[ -f "$ecc_toml" ]]; then
  install_tail=$(yq -r '.install.commands[]' "$ecc_toml" | tail -n +2)
  upgrade_tail=$(yq -r '.upgrade.commands[]' "$ecc_toml" | tail -n +2)
  if [[ "$install_tail" == "$upgrade_tail" ]]; then
    check "ecc: [install] and [upgrade] share one payload selection"
  else
    cross "ecc: [install] and [upgrade] diverge past the marketplace command"
    failures=$(( failures + 1 ))
  fi
fi

# `yq -e` without an output format re-encodes the match as TOML, which errors
# on an array and reads back as "key absent" -- the failure mode that silently
# skipped whole [upgrade] and [remove] blocks. Every existence probe in the
# runner must pass one.
runner="${DOTFILEDIR}/install/claude-addons.zsh"
if grep -n 'yq -e' "$runner" | grep -v -- '-o=json' | grep -q .; then
  cross "claude-addons.zsh: yq -e probe without -o=json (arrays read as absent):"
  grep -n 'yq -e' "$runner" | grep -v -- '-o=json'
  failures=$(( failures + 1 ))
else
  check "claude-addons.zsh: every yq -e probe sets an output format"
fi

if (( failures > 0 )); then
  cross "claude-addons manifest tests: ${failures} failure(s)"
  exit 1
fi

success "claude-addons manifest tests passed"
