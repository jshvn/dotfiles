#!/bin/zsh

# =============================================================================
# install/lint-rules.zsh -- shared lint detector bodies (LINT-02, LINT-03a)
#
# Purpose:      Single source of truth for the two lint detectors that the
#               production scan (taskfiles/lint.yml `taskfile`) AND the
#               self-test harness (`test-fixtures`) both need. Keeping one
#               implementation removes the verbatim-copy drift hazard the
#               fixture block used to warn about.
# Depends on:   yq, jq, ggrep, awk, sed (same toolchain as lint.yml).
# Side effects: none -- defines lint02_scan_file / lint03a_scan_file; both are
#               read-only (yq reads of the target taskfile) and print to stdout.
# =============================================================================

# Sourced into go-task's shell (NOT executed): no `set -euo pipefail` here --
# it would mutate the caller's shell options. Double-source guard mirrors
# install/messages.zsh.
[[ -n "${DOTFILES_LINT_RULES_LOADED:-}" ]] && return 0
DOTFILES_LINT_RULES_LOADED=1

# lint02_scan_file <taskfile>
# LINT-02: print each status: line that references a $VAR not defined in the
# same status entry (via `VAR=`, `for VAR in`, or `read [-flags] VAR`). Lines
# containing `$(` or the template-open token are dropped wholesale (a `$(`
# masks a legitimate `out=$(cmd)` define-line; the template open avoids
# matching go-task-rendered fragments). Empty output == no violation.
lint02_scan_file() {
  local f="$1" n i entry local_vars loop_vars read_vars allowed entry_hits out=""
  n=$(yq -o=json '[.tasks[] | select(.status) | .status[] | select(tag == "!!str")] | length' "$f" 2>/dev/null || echo 0)
  for ((i=0; i<n; i++)); do
    entry=$(yq -o=json "[.tasks[] | select(.status) | .status[] | select(tag == \"!!str\")][$i]" "$f" 2>/dev/null | jq -r .)
    local_vars=$(printf '%s\n' "$entry" \
      | ggrep -oE '(^|[[:space:];&|]+)[A-Za-z_][A-Za-z0-9_]*=' \
      | sed -E 's/^[^A-Za-z_]+//; s/=$//' || true)
    loop_vars=$(printf '%s\n' "$entry" \
      | ggrep -oE '\bfor[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in\b' \
      | awk '{print $2}' || true)
    # `read [-flags] VAR` defines VAR in the entry's shell context, same as a
    # `for VAR in` loop head (e.g. `while read -r rel`).
    read_vars=$(printf '%s\n' "$entry" \
      | ggrep -oE '\bread([[:space:]]+-[A-Za-z]+)*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
      | awk '{print $NF}' || true)
    # Space-separated: BSD awk rejects newlines in -v assignments ("awk:
    # newline in string"), which silently emptied entry_hits.
    allowed=$(printf '%s\n%s\n%s\n' "$local_vars" "$loop_vars" "$read_vars" | sort -u | ggrep -v '^$' | tr '\n' ' ' || true)
    entry_hits=$(printf '%s\n' "$entry" \
      | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
      | ggrep -vE '\$\(' \
      | ggrep -vE '\{\{' \
      | awk -v allowed="$allowed" '
          BEGIN {
            nlines = split(allowed, arr, " ")
            for (j = 1; j <= nlines; j++) if (arr[j] != "") locals[arr[j]] = 1
          }
          {
            ok = 1; rest = $0
            while (match(rest, /\$[A-Za-z_][A-Za-z0-9_]*/)) {
              v = substr(rest, RSTART + 1, RLENGTH - 1)
              if (!(v in locals)) { ok = 0; break }
              rest = substr(rest, RSTART + RLENGTH)
            }
            if (!ok) print $0
          }
        ' || true)
    if [[ -n "$entry_hits" ]]; then
      out="${out}${entry_hits}"$'\n'
    fi
  done
  printf '%s' "$out"
}

# lint03a_scan_file <taskfile>
# LINT-03a: print the name (one per line) of each task that has cmds: but no
# status:, excluding `internal: true` tasks and tasks whose cmds are ALL
# `task:` delegations. The `map(has("task")) | all` form is required -- the
# `all(has("task"))` form is a yq syntax error. Bracket-indexing
# `.tasks["$name"]` keeps the query robust when a task name collides with a yq
# builtin (e.g. "all"). Empty output == no violation. Callers decide messaging
# (the lint.yml-self skip stays in the production caller).
lint03a_scan_file() {
  local f="$1" task_name is_internal all_delegations
  while IFS= read -r task_name; do
    [[ -z "$task_name" ]] && continue
    is_internal=$(yq ".tasks.\"$task_name\".internal // false" "$f" 2>/dev/null || echo false)
    [[ "$is_internal" == "true" ]] && continue
    all_delegations=$(yq ".tasks[\"$task_name\"].cmds | map(has(\"task\")) | all" "$f" 2>/dev/null || echo false)
    [[ "$all_delegations" == "true" ]] && continue
    printf '%s\n' "$task_name"
  done < <(yq '.tasks | to_entries | .[] | select(.value | has("cmds")) | select(.value | has("status") | not) | .key' "$f" 2>/dev/null || true)
}
