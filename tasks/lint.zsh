#!/bin/zsh

# =============================================================================
# tasks/lint.zsh -- static checks on the zsh and Nix sources
#
# Purpose:      The rules that survive the move to Nix: every .zsh parses
#               (zsh -n), every executable .zsh sets -euo pipefail, every .zsh
#               carries the Purpose / Depends on / Side effects banner, and no
#               source hardcodes /opt/homebrew or /usr/local outside a line
#               marked `# lint-allow: hardcoded-prefix`, and every task in
#               Taskfile.yml has a row in the default menu. Nix formatting is
#               checked by `task lint` separately with `nix fmt -- --ci`.
# Depends on:   zsh; ggrep (GNU grep); tasks/messages.zsh.
# Side effects: none.
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
typeset -r ROOT="${HERE:h}"
source "$HERE/messages.zsh"
failed=0

zsh_files=("$ROOT"/*.zsh(.N) "$ROOT"/{apps,system,tasks,shell,identity}/**/*.zsh(.N) "$ROOT"/shell/.z*(.N))

info "zsh -n"
for f in $zsh_files; do
  if ! zsh -n "$f" 2>/dev/null; then
    cross "${f#$ROOT/}: does not parse"
    failed=1
  fi
done
check "${#zsh_files} files parsed"

info "executables set -euo pipefail"
for f in $zsh_files; do
  if [[ -x "$f" ]] && ! head -30 "$f" | ggrep -qE '^set -euo pipefail$'; then
    cross "${f#$ROOT/}: executable without set -euo pipefail"
    failed=1
  fi
done

info "banner headers"
for f in $zsh_files; do
  head=$(head -40 "$f")
  for label in '# Purpose:' '# Depends on:' '# Side effects:'; do
    if ! ggrep -qF "$label" <<< "$head"; then
      cross "${f#$ROOT/}: banner lacks '$label'"
      failed=1
    fi
  done
done

info "no hardcoded Homebrew prefix"
# comment lines are prose, not paths
pattern='/opt/homebrew|/usr/local' # lint-allow: hardcoded-prefix
hits=$(ggrep -rnE "$pattern" "$ROOT" --include='*.nix' --include='*.zsh' --include='Taskfile.yml' \
  | ggrep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | ggrep -vF 'lint-allow: hardcoded-prefix' || true)
if [[ -n "$hits" ]]; then
  while IFS= read -r line; do
    cross "${line#$ROOT/}"
  done <<< "$hits"
  failed=1
else
  check "none outside annotated lines"
fi

info "every task in the task menu"
taskfile="$ROOT/Taskfile.yml"
menu=$(awk '/^  default:$/ { f = 1; next } /^  [a-z][a-z:-]*:$/ { f = 0 } f' "$taskfile")
tasks=(${(f)"$(awk '/^tasks:$/ { t = 1 } t && /^  [a-z][a-z:-]*:$/ { sub(/^  /, ""); sub(/:$/, ""); print }' "$taskfile")"})
tasks=(${tasks:#default})
for t in $tasks; do
  if ! ggrep -qE "row 'task ${t}[ ']" <<< "$menu"; then
    cross "Taskfile.yml: task $t has no row in the default menu"
    failed=1
  fi
done
check "${#tasks} tasks have a row"

exit $failed
