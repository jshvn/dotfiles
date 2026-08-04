#!/bin/zsh

# =============================================================================
# install/compose-brewfile.zsh -- compose per-machine Brewfile from manifest
#
# Purpose:      Read $XDG_STATE_HOME/dotfiles/resolved.json and emit a
#               composed per-machine Brewfile to
#               $XDG_STATE_HOME/dotfiles/build/Brewfile (atomic mktemp + mv).
# Depends on:   jq (>= 1.7), zsh (>= 5); install/messages.zsh.
# Side effects: writes $XDG_STATE_HOME/dotfiles/build/Brewfile.
# =============================================================================

set -euo pipefail

# Output structure (composed Brewfile written to the build dir):
#   Line 1    -- AUTO-GENERATED header banner (ISO-8601 UTC timestamp)
#   Lines 2-5 -- Machine: / Bundles: / Extras: counts / DO NOT EDIT notice
#   Body      -- typed extras emitted as Ruby DSL lines, in fixed order:
#                  taps -> formulae -> casks -> mas -> vscode -> cargo -> uv -> npm
#                taps lead so a third-party tap is registered before the
#                qualified entry that needs it.
#
# The resolver folds the base tier (manifests/base.toml) and every enabled
# feature's [<flag>.packages] buckets into resolved.json's
# packages.brew.{formulae,casks,mas} during resolve, so the composer reads a
# single flat package set.
#
# Extras line shapes (canonical; literal single-quotes around the name):
#   tap '<user>/<tap>'                         (third-party tap, from a qualified name)
#   brew '<name>'[, trusted: true]             (formula; trusted when qualified)
#   cask '<name>'[, trusted: true]             (cask; trusted when qualified)
#   mas  '<name>', id: <id>                    (Mac App Store entry)
#   vscode '<id>'                              (VSCode extension; needs `code`)
#   cargo  '<name>'                            (Rust crate -- cargo install)
#   uv     '<name>'                            (Python tool -- uv tool install)
#   npm    '<name>'                            (global npm package -- needs node)
#
# packages:verify is brew-info-driven. Package
# names are validated against a strict allow-list at resolve time; the `esc`
# gsub in the emit below escapes any stray single quote as a second guard so a
# name can never break out of the Ruby string literal a Brewfile line is.
#
# .packages.brew.{formulae,casks,mas} hold the full package set for the
# machine: the union of the base tier, every enabled feature's packages, and
# the machine's inline entries (deduped, machine wins).

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task packages:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r RESOLVED_JSON="${STATE_DIR}/resolved.json"
typeset -r MACHINE_FILE="${STATE_DIR}/machine"
typeset -r BUILD_DIR="${STATE_DIR}/build"
typeset -r COMPOSED_OUT="${BUILD_DIR}/Brewfile"

# Literal single-quote (U+0027) injected as a jq --arg parameter so jq
# filter strings can stay inside zsh single-quote wrapping with no brittle
# nested shell-escape sequences. jq supports JSON \uXXXX escapes only, not
# \xHH, so injecting the byte as data via --arg is the canonical approach.
typeset -r SQ=$'\x27'

# read_machine_name: header-banner helper; never load-bearing for compose
# correctness. Falls back from $MACHINE_FILE to .meta.description to "unknown".
read_machine_name() {
  local name=""
  if [[ -s "$MACHINE_FILE" ]]; then
    read -r name < "$MACHINE_FILE" || true
  fi
  if [[ -z "$name" ]]; then
    name=$(jq -r '.meta.description // "unknown"' "$RESOLVED_JSON" 2>/dev/null || echo "unknown")
  fi
  echo "${name:-unknown}"
}

# compose <out_tmp> <formulae_json> <casks_json> <mas_json>
compose() {
  local out_tmp="$1"
  local formulae_json="$2"
  local casks_json="$3"
  local mas_json="$4"

  local timestamp machine_name
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  machine_name=$(read_machine_name)

  local n_formulae n_casks n_mas
  n_formulae=$(echo "$formulae_json" | jq -r 'length')
  n_casks=$(echo "$casks_json"       | jq -r 'length')
  n_mas=$(echo "$mas_json"           | jq -r 'length')

  # Non-brew package-manager buckets (Homebrew >= 6.0 brew bundle entry types).
  local vscode_json cargo_json uv_json npm_json
  vscode_json=$(jq -c '.packages.vscode.extensions // []' "$RESOLVED_JSON")
  cargo_json=$(jq -c  '.packages.cargo.crates      // []' "$RESOLVED_JSON")
  uv_json=$(jq -c     '.packages.uv.tools          // []' "$RESOLVED_JSON")
  npm_json=$(jq -c    '.packages.npm.packages      // []' "$RESOLVED_JSON")
  local n_vscode n_cargo n_uv n_npm
  n_vscode=$(echo "$vscode_json" | jq -r 'length')
  n_cargo=$(echo  "$cargo_json"  | jq -r 'length')
  n_uv=$(echo     "$uv_json"     | jq -r 'length')
  n_npm=$(echo    "$npm_json"    | jq -r 'length')

  {
    echo "# AUTO-GENERATED by task packages:compose on ${timestamp}"
    echo "# Machine:  ${machine_name}"
    echo "# Packages: ${n_formulae} formulae, ${n_casks} casks, ${n_mas} mas"
    echo "# Managers: ${n_vscode} vscode, ${n_cargo} cargo, ${n_uv} uv, ${n_npm} npm"
    echo "# DO NOT EDIT -- regenerated on every task install."
    echo ""

    # Canonical jq emit forms. Formulae are bare strings; casks are
    # { name } objects (resolver wraps them on output). SQ passed as $q so the
    # jq filter stays inside zsh single-quote wrapping and never contains a
    # literal quote. `esc` escapes any embedded single quote as Ruby `\'` --
    # defense in depth, since the resolver's PACKAGE_NAME_RE already rejects
    # such names, but a Brewfile is executed Ruby and must never emit an
    # unescaped quote. gsub($q; "\\"+$q) replaces `'` with `\'`.
    # A fully-qualified name (<user>/<tap>/<name>) names a third-party tap.
    # Homebrew refuses to load such an entry unless the tap is trusted, and the
    # refusal is a hard error rather than a prompt, so the composer declares
    # both the tap and the grant. The qualified name in a reviewed, tracked
    # manifest is the consent; nothing needs to be confirmed on the machine.
    echo "# === taps ==="
    { echo "$formulae_json" | jq -r '.[]'
      echo "$casks_json"    | jq -r '.[].name'
    } | ggrep -E '^[^/]+/[^/]+/[^/]+$' \
      | sed -E 's#^([^/]+/[^/]+)/.*#\1#' \
      | sort -u \
      | while IFS= read -r tap_name; do
          printf "tap '%s'\n" "$tap_name"
        done

    echo "# === formulae ==="
    echo "$formulae_json" | jq -r --arg q "$SQ" '
      def esc: gsub($q; "\\"+$q);
      def qualified: test("^[^/]+/[^/]+/[^/]+$");
      .[] | "brew " + $q + (. | esc) + $q + (if qualified then ", trusted: true" else "" end)'

    echo "# === casks ==="
    echo "$casks_json" | jq -r --arg q "$SQ" '
      def esc: gsub($q; "\\"+$q);
      .[] | .name
      | "cask " + $q + (. | esc) + $q
        + (if test("^[^/]+/[^/]+/[^/]+$") then ", trusted: true" else "" end)'

    echo "# === mas ==="
    echo "$mas_json" | jq -r --arg q "$SQ" 'def esc: gsub($q; "\\"+$q); .[] | "mas " + $q + (.name | esc) + $q + ", id: " + (.id | tostring)'

    # Non-brew managers emitted after casks/mas so the providing cask (e.g.
    # visual-studio-code for vscode) is installed first. Each is a bare-string
    # array; the entry id is the line argument verbatim.
    echo "# === vscode ==="
    echo "$vscode_json" | jq -r --arg q "$SQ" 'def esc: gsub($q; "\\"+$q); .[] | "vscode " + $q + (. | esc) + $q'

    echo "# === cargo ==="
    echo "$cargo_json" | jq -r --arg q "$SQ" 'def esc: gsub($q; "\\"+$q); .[] | "cargo " + $q + (. | esc) + $q'

    echo "# === uv ==="
    echo "$uv_json" | jq -r --arg q "$SQ" 'def esc: gsub($q; "\\"+$q); .[] | "uv " + $q + (. | esc) + $q'

    echo "# === npm ==="
    echo "$npm_json" | jq -r --arg q "$SQ" 'def esc: gsub($q; "\\"+$q); .[] | "npm " + $q + (. | esc) + $q'
  } > "$out_tmp"
}

main() {
  if [[ ! -s "$RESOLVED_JSON" ]]; then
    error "resolved.json missing or empty: ${RESOLVED_JSON}"
    error "  run: task setup -- <machine-name>"
    return 1
  fi

  # `// []` covers the case where a sub-array is absent (defense-in-depth
  # for ad-hoc resolved.json variants where defaults didn't supply the shape).
  local formulae_json casks_json mas_json
  formulae_json=$(jq -c '.packages.brew.formulae // []' "$RESOLVED_JSON")
  casks_json=$(jq -c    '.packages.brew.casks    // []' "$RESOLVED_JSON")
  mas_json=$(jq -c      '.packages.brew.mas      // []' "$RESOLVED_JSON")

  # Atomic write: mktemp in the same directory as the destination so `mv`
  # is an atomic rename across the same filesystem (POSIX rename(2)).
  # Signal trap mirrors resolver.zsh: clean up the tmp file on EXIT/INT/TERM,
  # then clear the trap once the rename completes so the (now-renamed)
  # destination is not subsequently rm'd.
  mkdir -p "$BUILD_DIR"
  local tmp
  tmp=$(mktemp "${COMPOSED_OUT}.XXXXXX")
  trap 'rm -f "$tmp"' EXIT INT TERM
  {
    compose "$tmp" "$formulae_json" "$casks_json" "$mas_json"
    mv "$tmp" "$COMPOSED_OUT"
  } || {
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 1
  }
  trap - EXIT INT TERM

  check "composed Brewfile -> ${COMPOSED_OUT}"
  return 0
}

main "$@"
