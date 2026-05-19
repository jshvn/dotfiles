#!/bin/zsh
# -----------------------------------------------------------------------------
# install/compose-brewfile.zsh -- compose per-machine Brewfile from manifest
#
# Sourced from: taskfiles/packages.yml (packages:compose, packages:install
#               tasks; Plan 04). Also runnable directly via
#               `zsh install/compose-brewfile.zsh` for ad-hoc compose.
#
# Reads:        $XDG_STATE_HOME/dotfiles/resolved.json   (compiled manifest)
#               $DOTFILEDIR/packages/<bundle>.rb          (one per declared
#                                                         bundle name)
# Writes:       $XDG_CACHE_HOME/dotfiles/Brewfile        (atomic mktemp+mv)
# Depends on:   jq (>= 1.7), zsh (>= 5)
#
# Hard-fails (exit 1) if $XDG_STATE_HOME/dotfiles/resolved.json is missing
# or empty -- caller must run `task setup -- <machine-name>` first.
#
# See the "Output structure" and "Extras line shapes" notes below the
# set -euo pipefail line for the composed-Brewfile format reference.
# -----------------------------------------------------------------------------

set -euo pipefail

# Output structure (composed Brewfile written to $XDG_CACHE_HOME/dotfiles/Brewfile):
#   Line 1   -- AUTO-GENERATED header banner (ISO-8601 UTC timestamp)
#   Lines 2-5 -- Machine: / Bundles: / Extras: counts / DO NOT EDIT notice
#   Body     -- each declared bundle (packages/<name>.rb) concatenated verbatim
#               in declared order, with section separators
#   Tail     -- typed extras as Ruby DSL lines (formulae / casks / mas)
#
# Extras line shapes (canonical; literal single-quotes around the name):
#   brew '<name>'                              (formula -- string OR {name,...} object)
#   cask '<name>'                              (cask; verify is data-driven from brew info)
#   mas  '<name>', id: <id>                    (Mac App Store entry)
#
# Note: post-Gap-2 (Plan 05-07/05-08), `packages:verify` is brew-info-driven,
# not bundle-comment-driven. The schema still permits {name, verify} formula
# objects (docs/MANIFEST.md:105 backward-compat) but the `verify` field is
# ignored on emit -- both string and object shapes produce the bare `brew '<name>'`
# line. No per-line `# verify:` comments are emitted.

# Source the messages library. messages.zsh handles its own set -u-safe
# double-source guard via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u contract` block);
# a bare source is sufficient and idempotent under `set -euo pipefail`.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task packages:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r RESOLVED_JSON="${STATE_DIR}/resolved.json"
typeset -r MACHINE_FILE="${STATE_DIR}/machine"
typeset -r CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
typeset -r COMPOSED_OUT="${CACHE_DIR}/Brewfile"
typeset -r BUNDLES_DIR="${DOTFILEDIR}/packages"

# Literal single-quote (U+0027), passed to jq as a --arg parameter so the
# jq filter strings can stay inside zsh single-quote wrapping with no
# brittle shell-escape nested-quote sequences anywhere. The plan author's
# original "jq \x27" proposal is jq-invalid (jq supports JSON \uXXXX
# escapes only -- not \xHH); injecting the byte as data via --arg is the
# canonical alternative that preserves the same correctness goal (literal
# single-quote delimiters on every emitted brew/cask/mas line).
typeset -r SQ=$'\x27'

# -----------------------------------------------------------------------------
# read_machine_name
# Return the active machine name from $STATE_DIR/machine if it exists, else
# fall back to .meta.description from resolved.json, else "unknown". Used
# only for the header banner; never load-bearing for compose correctness.
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# compose <out_tmp> <formulae_json> <casks_json> <mas_json>
# Write the full composed Brewfile content to $1 (a tmp path). Reads bundle
# names from resolved.json, concatenates packages/<bundle>.rb in declared
# order, then emits typed-extras as Ruby DSL lines via three canonical jq
# filters (formulae / casks / mas).
# -----------------------------------------------------------------------------
compose() {
  local out_tmp="$1"
  local formulae_json="$2"
  local casks_json="$3"
  local mas_json="$4"

  local timestamp machine_name
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  machine_name=$(read_machine_name)

  # Bundle list (space-separated for the header; array for iteration).
  local -a bundles
  bundles=( $(jq -r '.packages.brew.bundles[]' "$RESOLVED_JSON") )

  local bundles_csv=""
  local b
  for b in "${bundles[@]}"; do
    if [[ -z "$bundles_csv" ]]; then
      bundles_csv="$b"
    else
      bundles_csv="${bundles_csv}, $b"
    fi
  done

  # Extras counts for the header banner.
  local n_formulae n_casks n_mas
  n_formulae=$(echo "$formulae_json" | jq -r 'length')
  n_casks=$(echo "$casks_json"       | jq -r 'length')
  n_mas=$(echo "$mas_json"           | jq -r 'length')

  {
    echo "# AUTO-GENERATED by task packages:compose on ${timestamp}"
    echo "# Machine:  ${machine_name}"
    echo "# Bundles:  ${bundles_csv}"
    echo "# Extras:   ${n_casks} casks, ${n_mas} mas, ${n_formulae} formulae"
    echo "# DO NOT EDIT -- regenerated on every task install."
    echo ""

    for b in "${bundles[@]}"; do
      echo "# === bundle: ${b}.rb ==="
      cat "${BUNDLES_DIR}/${b}.rb"
      echo ""
    done

    # ---- Extras: formulae ---------------------------------------------------
    # Canonical jq emit form (formulae): "brew '<name>'" for both shapes.
    # Schema accepts bare strings OR {name, ...} objects (backward-compat per
    # docs/MANIFEST.md:105). Both shapes emit the same bare brew line; the
    # legacy {name, verify} object's `verify` field is ignored on emit because
    # `packages:verify` is brew-info-driven post-Gap-2 (Plan 05-07/05-08), not
    # bundle-comment-driven.
    # The literal single-quote (U+0027) is injected as the jq parameter $q
    # (set from the SQ constant above) so the jq filter stays inside zsh
    # single-quote wrapping with no nested shell-escape needed.
    echo "# === extras (formulae) ==="
    echo "$formulae_json" | jq -r --arg q "$SQ" '.[] | if type == "string" then "brew " + $q + . + $q else "brew " + $q + .name + $q end'

    # ---- Extras: casks ------------------------------------------------------
    # Canonical jq emit form (casks): "cask '<name>'" (bare; verify is
    # data-driven from `brew info --installed --json=v2` post-Gap-2 pivot).
    echo "# === extras (casks) ==="
    echo "$casks_json" | jq -r --arg q "$SQ" '.[] | "cask " + $q + .name + $q'

    # ---- Extras: mas --------------------------------------------------------
    # Canonical jq emit form (mas): "mas '<name>', id: <id>".
    echo "# === extras (mas) ==="
    echo "$mas_json" | jq -r --arg q "$SQ" '.[] | "mas " + $q + .name + $q + ", id: " + (.id | tostring)'
  } > "$out_tmp"
}

# -----------------------------------------------------------------------------
# main
# Hard-fail on missing resolved.json; read typed extras from resolved.json;
# validate every declared bundle file exists; compose to a tmp file with a
# signal-safe trap; atomically rename to $COMPOSED_OUT.
# -----------------------------------------------------------------------------
main() {
  # D-16: missing-state hard-fail with actionable message naming the canonical
  # setup task. resolver.zsh:474-481 ships this exact pattern.
  if [[ ! -s "$RESOLVED_JSON" ]]; then
    error "resolved.json missing or empty: ${RESOLVED_JSON}"
    error "  run: task setup -- <machine-name>"
    return 1
  fi

  # Read typed-bucket extras from resolved.json. The `// []` fallback covers
  # the case where a sub-array is absent (defaults supplies the shape per
  # Plan 02 migration; this is defense-in-depth for ad-hoc resolved.json
  # variants).
  local formulae_json casks_json mas_json
  formulae_json=$(jq -c '.packages.brew.extra_packages.formulae // []' "$RESOLVED_JSON")
  casks_json=$(jq -c    '.packages.brew.extra_packages.casks    // []' "$RESOLVED_JSON")
  mas_json=$(jq -c      '.packages.brew.extra_packages.mas      // []' "$RESOLVED_JSON")

  # Validate bundle files exist BEFORE writing anything -- fail-fast keeps
  # the cache directory free of half-composed Brewfile.* tmp files when a
  # typo or missing bundle would abort mid-stream anyway.
  local -a bundles
  bundles=( $(jq -r '.packages.brew.bundles[]' "$RESOLVED_JSON") )
  local b
  for b in "${bundles[@]}"; do
    if [[ ! -f "${BUNDLES_DIR}/${b}.rb" ]]; then
      error "bundle file not found: ${BUNDLES_DIR}/${b}.rb"
      error "  declared in: ${RESOLVED_JSON} (.packages.brew.bundles)"
      return 1
    fi
  done

  # Atomic write: mktemp in the same directory as the destination so
  # `mv` is an atomic rename across the same filesystem (POSIX rename(2)).
  # Signal trap mirrors resolver.zsh:341-368 verbatim: clean up the tmp
  # file on EXIT/INT/TERM, then clear the trap once the rename completes
  # so the (now-renamed) destination is not subsequently rm'd.
  mkdir -p "$CACHE_DIR"
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
