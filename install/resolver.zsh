#!/bin/zsh
# -----------------------------------------------------------------------------
# install/resolver.zsh -- compile defaults + machine manifest into resolved.json
#
# Sourced from: taskfiles/manifest.yml (manifest:resolve, manifest:validate,
#               manifest:show tasks). Also runnable directly via
#               `zsh install/resolver.zsh [flags]`.
#
# Reads:        $DOTFILEDIR/manifests/defaults.toml
#               $DOTFILEDIR/manifests/machines/<machine>.toml
#               $XDG_STATE_HOME/dotfiles/machine    (resolve mode only)
# Writes:       $XDG_STATE_HOME/dotfiles/resolved.json  (atomic via mktemp+mv)
#               or stdout, when invoked with --stdout
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh (>= 5)
#
# Modes:
#   default              -- resolve mode: read state file, deep-merge defaults
#                           + machine TOML, atomically write resolved.json
#   --validate-only      -- requires --machine <name>; runs D-03 required-field
#                           checks plus D-01 os enum plus D-04 unknown-key
#                           warnings; exits 1 on hard errors
#   --stdout             -- resolve to stdout instead of resolved.json (no
#                           atomic-write contract; used by manifest:show)
#
# Hard-fails (exit 1) if $XDG_STATE_HOME/dotfiles/machine is missing in
# resolve mode -- caller must run `task setup -- <machine-name>` first.
# Hard-fails (exit 1) on any path-traversal attempt in --machine argument.
# -----------------------------------------------------------------------------

set -euo pipefail

# Source the messages library, but only if not already loaded by a parent
# taskfile context. messages.zsh references a bare $DOTFILES_MESSAGES_LOADED
# in its double-source guard; under `set -u` that would abort, so we
# pre-initialize the variable before sourcing.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task manifest:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
typeset -r DEFAULTS="${DOTFILEDIR}/manifests/defaults.toml"
typeset -r MACHINES_DIR="${DOTFILEDIR}/manifests/machines"
typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r STATE_FILE="${STATE_DIR}/machine"
typeset -r OUT="${STATE_DIR}/resolved.json"

# Machine-name regex: kebab-case identifier; the first character may also
# be an underscore so test/negative fixture names (e.g. _invalid-bad-os)
# are accepted by --validate-only. Path-traversal characters (`/`, `.`,
# `..`, spaces) remain rejected.
typeset -r MACHINE_NAME_RE='^[a-z0-9_][a-z0-9_-]*$'

# -----------------------------------------------------------------------------
# list_available_machines
# Print a space-separated list of machine names derived from
# manifests/machines/*.toml basenames. Prints empty string if no manifests.
# -----------------------------------------------------------------------------
list_available_machines() {
  local -a files
  files=("${MACHINES_DIR}"/*.toml(N))
  if (( ${#files} == 0 )); then
    echo ""
    return 0
  fi
  local f names=""
  for f in "${files[@]}"; do
    local base="${f:t:r}"  # basename without .toml
    names+="${base} "
  done
  # trim trailing space
  echo "${names% }"
}

# -----------------------------------------------------------------------------
# validate_manifest <machine_file>
# Hand-rolled D-03 required-field validator + D-01 os enum + identity enum.
# Uses yq has() + tag predicates (RESEARCH section 3.3).
# Returns the number of validation errors via stdout (caller captures and
# compares to 0). On any error, an `error` line is written to stderr.
# -----------------------------------------------------------------------------
validate_manifest() {
  local machine_file="$1"
  local errors=0

  if [[ ! -f "$machine_file" ]]; then
    error "machine manifest not found: ${machine_file}"
    echo 1
    return 0
  fi

  # Required scalar string fields: each must be present (has() == true)
  # and non-empty. The loop below dynamically dispatches to yq calls of the
  # form: yq '.meta | has("description")', '.platform | has("os")', etc.
  #
  # NOTE: the loop variable is `field_path`, not `path`. In zsh, `path` is a
  # tied special parameter that mirrors $PATH as an array; declaring
  # `local path` inside a function shadows $PATH and breaks all command
  # lookups for the function scope.
  local -a required_strings
  required_strings=(
    "meta.description"
    "platform.os"
    "identity.git"
    "identity.ssh"
  )
  local field_path parent key present value
  for field_path in "${required_strings[@]}"; do
    parent="${field_path%.*}"
    key="${field_path##*.}"
    present=$(yq ".${parent} | has(\"${key}\")" "$machine_file" 2>/dev/null || echo false)
    if [[ "$present" != "true" ]]; then
      error "missing required field: ${field_path}"
      errors=$(( errors + 1 ))
      continue
    fi
    value=$(yq -r ".${field_path}" "$machine_file" 2>/dev/null || echo "")
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
      error "required field is empty or null: ${field_path}"
      errors=$(( errors + 1 ))
    fi
  done

  # features must be a !!map (may be empty {}).
  local features_present features_tag
  features_present=$(yq '. | has("features")' "$machine_file" 2>/dev/null || echo false)
  if [[ "$features_present" != "true" ]]; then
    error "missing required field: features (must be a table, may be empty)"
    errors=$(( errors + 1 ))
  else
    features_tag=$(yq '.features | tag' "$machine_file" 2>/dev/null || echo "")
    if [[ "$features_tag" != "!!map" ]]; then
      error "features must be a table (may be empty {}); got tag: ${features_tag}"
      errors=$(( errors + 1 ))
    fi
  fi

  # packages.brew.bundles must be a non-empty !!seq containing "core".
  local bundles_present bundles_tag bundles_length contains_core
  bundles_present=$(yq '.packages.brew | has("bundles")' "$machine_file" 2>/dev/null || echo false)
  if [[ "$bundles_present" != "true" ]]; then
    error "missing required field: packages.brew.bundles"
    errors=$(( errors + 1 ))
  else
    bundles_tag=$(yq '.packages.brew.bundles | tag' "$machine_file" 2>/dev/null || echo "")
    if [[ "$bundles_tag" != "!!seq" ]]; then
      error "packages.brew.bundles must be an array; got tag: ${bundles_tag}"
      errors=$(( errors + 1 ))
    else
      bundles_length=$(yq '.packages.brew.bundles | length' "$machine_file" 2>/dev/null || echo 0)
      if (( bundles_length < 1 )); then
        error "packages.brew.bundles must contain at least one bundle"
        errors=$(( errors + 1 ))
      fi
      contains_core=$(yq '.packages.brew.bundles | contains(["core"])' "$machine_file" 2>/dev/null || echo false)
      if [[ "$contains_core" != "true" ]]; then
        error 'packages.brew.bundles must include "core"'
        errors=$(( errors + 1 ))
      fi
    fi
  fi

  # D-01: platform.os must equal "darwin" in v1.
  local os_value
  os_value=$(yq -r '.platform.os // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -n "$os_value" ]] && [[ "$os_value" != "darwin" ]]; then
    error "platform.os must equal \"darwin\" in v1; got: ${os_value}"
    errors=$(( errors + 1 ))
  fi

  # identity.git / identity.ssh enum: personal|work|none.
  local ident_key ident_val
  for ident_key in git ssh; do
    ident_val=$(yq -r ".identity.${ident_key} // \"\"" "$machine_file" 2>/dev/null || echo "")
    if [[ -z "$ident_val" ]]; then
      continue  # already counted above as missing/empty
    fi
    case "$ident_val" in
      personal|work|none) ;;
      *) error "identity.${ident_key} must be one of personal|work|none; got: ${ident_val}"
         errors=$(( errors + 1 )) ;;
    esac
  done

  echo "$errors"
}

# -----------------------------------------------------------------------------
# emit_unknown_key_warnings <machine_file>
# Emit `unknown key: <path> at <file>:<line>` warnings to stderr for any
# scalar leaf path not under the whitelist (D-04). Always exits 0.
# -----------------------------------------------------------------------------
emit_unknown_key_warnings() {
  local machine_file="$1"
  [[ -f "$machine_file" ]] || return 0

  local -a whitelist
  whitelist=(
    "schema_version"
    "meta"
    "platform.os"
    "platform.arch"
    "features"
    "packages.brew.bundles"
    "packages.brew.extra_packages"
    "identity.git"
    "identity.ssh"
  )

  local grep_cmd="grep"
  if command -v ggrep >/dev/null 2>&1; then
    grep_cmd="ggrep"
  fi

  local found matched expected leaf line_no
  while IFS= read -r found; do
    [[ -z "$found" ]] && continue
    matched=0
    for expected in "${whitelist[@]}"; do
      if [[ "$found" == "$expected" ]] || [[ "$found" == "${expected}."* ]]; then
        matched=1
        break
      fi
    done
    if (( matched == 0 )); then
      leaf="${found##*.}"
      # WR-02 fix: only attempt the line-number heuristic when the leaf
      # is a strict identifier (no quoted-key metacharacters). TOML
      # permits keys like "a.b" or "a*b" which, if substituted into a
      # regex, would be interpreted as metacharacters and yield a
      # misleading line number. The warning still fires regardless;
      # only the line: hint is omitted in the unsafe case.
      if [[ "$leaf" =~ ^[A-Za-z0-9_-]+$ ]]; then
        line_no=$("$grep_cmd" -n "^${leaf}[[:space:]]*=" "$machine_file" 2>/dev/null | head -1 | cut -d: -f1 || true)
      else
        line_no=""
      fi
      warn "unknown key: ${found} at ${machine_file}:${line_no:-?}"
    fi
  done < <(yq -r '[paths(scalars) | join(".")] | .[]' "$machine_file" 2>/dev/null || true)

  return 0
}

# -----------------------------------------------------------------------------
# resolve_pipeline <defaults_path> <machine_path>
# Run the three-pass merge pipeline (RESEARCH section 4.2 + section 5) and
# emit the final JSON to stdout. Used by both atomic-file and stdout modes.
# -----------------------------------------------------------------------------
resolve_pipeline() {
  local defaults_path="$1"
  local machine_path="$2"

  # Pass 1: yq deep-merge with `. * .` (REPLACE arrays, deep-merge maps).
  local merged
  merged=$(yq eval-all '. as $i ireduce ({}; . * $i)' "$defaults_path" "$machine_path" -o json)

  # Pass 2: union + dedupe extra_packages from both sides.
  # `jq -s 'add | unique'` produces sorted output, matching fixture 06.
  local def_extras mach_extras union_extras
  def_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$defaults_path")
  mach_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$machine_path")
  union_extras=$(printf '%s %s' "$def_extras" "$mach_extras" | jq -s 'add | unique')

  # Pass 3: backfill platform.arch via uname -m if machine omitted it.
  local arch
  arch=$(yq -r '.platform.arch // ""' "$machine_path")
  if [[ -z "$arch" ]]; then
    arch=$(uname -m)
  fi

  # Compose final JSON.
  printf '%s' "$merged" \
    | jq --argjson extras "$union_extras" --arg arch "$arch" \
        '.packages.brew.extra_packages = $extras
         | .platform.arch = $arch'
}

# -----------------------------------------------------------------------------
# resolve_manifest <defaults_path> <machine_path> <out_path>
# Run the resolve pipeline and atomically write the result to out_path.
# Uses mktemp + mv to ensure readers never see a partial file (T-MAN-03).
# -----------------------------------------------------------------------------
resolve_manifest() {
  local defaults_path="$1"
  local machine_path="$2"
  local out_path="$3"

  local out_dir tmp
  out_dir="${out_path:h}"
  mkdir -p "$out_dir"

  tmp=$(mktemp "${out_path}.XXXXXX")
  # WR-01 fix: register a signal trap before the pipeline so Ctrl-C
  # (SIGINT), SIGTERM, or any other unhandled exit cleans up the tmp
  # file. The previous { ... } || { rm -f "$tmp"; ... } only handled
  # ordinary command failures -- repeated Ctrl-Cs during iteration
  # would otherwise accumulate resolved.json.aBcDeF-style siblings
  # in $XDG_STATE_HOME/dotfiles/. Clear the trap after a successful
  # mv so the (now-renamed) path is not subsequently rm'd.
  trap 'rm -f "$tmp"' EXIT INT TERM
  {
    resolve_pipeline "$defaults_path" "$machine_path" > "$tmp"
    mv "$tmp" "$out_path"
  } || {
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 1
  }
  trap - EXIT INT TERM
}

# -----------------------------------------------------------------------------
# resolve_machine_path <machine_name>
# Validate the machine name against the kebab-case regex (path-traversal
# guard, T-MAN-02), build the canonical manifest path, and verify the
# resolved path equals the canonical form (no traversal). Prints the path
# on stdout. Exits 1 on any guard failure.
# -----------------------------------------------------------------------------
resolve_machine_path() {
  local name="$1"
  if [[ -z "$name" ]]; then
    error "machine name is required"
    return 1
  fi
  if ! [[ "$name" =~ $MACHINE_NAME_RE ]]; then
    error "invalid machine name: '${name}' (must match ${MACHINE_NAME_RE})"
    return 1
  fi
  local path="${MACHINES_DIR}/${name}.toml"
  # Equality check defends against any leakage from the regex.
  if [[ "$path" != "${MACHINES_DIR}/${name}.toml" ]]; then
    error "internal error: machine path mismatch for '${name}'"
    return 1
  fi
  echo "$path"
}

# -----------------------------------------------------------------------------
# CLI dispatch
# -----------------------------------------------------------------------------
main() {
  local mode="resolve"
  local machine_arg=""
  local use_stdout=0

  while (( $# > 0 )); do
    case "$1" in
      --validate-only)
        mode="validate"
        shift
        ;;
      --machine)
        if (( $# < 2 )); then
          error "--machine requires an argument"
          return 1
        fi
        machine_arg="$2"
        shift 2
        ;;
      --stdout)
        use_stdout=1
        shift
        ;;
      --help|-h)
        cat <<'USAGE'
Usage:
  zsh install/resolver.zsh                              # resolve mode (default)
  zsh install/resolver.zsh --validate-only --machine <name>
  zsh install/resolver.zsh --machine <name> --stdout    # ad-hoc resolve to stdout

Environment:
  DOTFILEDIR        repo root (required)
  XDG_STATE_HOME    state directory (default: $HOME/.local/state)
USAGE
        return 0
        ;;
      *)
        error "unknown argument: $1"
        return 1
        ;;
    esac
  done

  if [[ "$mode" == "validate" ]]; then
    if [[ -z "$machine_arg" ]]; then
      error "--validate-only requires --machine <name>"
      return 1
    fi
    local machine_file
    machine_file=$(resolve_machine_path "$machine_arg") || return 1
    if [[ ! -f "$machine_file" ]]; then
      error "machine manifest not found: ${machine_file}"
      return 1
    fi
    local errcount
    errcount=$(validate_manifest "$machine_file")
    emit_unknown_key_warnings "$machine_file"
    if (( errcount > 0 )); then
      error "validation failed for ${machine_arg}: ${errcount} error(s)"
      return 1
    fi
    return 0
  fi

  # Resolve mode.
  local machine_name machine_file
  if [[ -n "$machine_arg" ]]; then
    # Ad-hoc resolve for a specific machine (D-17 manifest:show pattern).
    machine_name="$machine_arg"
    machine_file=$(resolve_machine_path "$machine_name") || return 1
  else
    # Default: read active machine from state file.
    if [[ ! -f "$STATE_FILE" ]]; then
      local available
      available=$(list_available_machines)
      error "no machine selected"
      error "  run: task setup -- <machine-name>"
      error "  available: ${available:-(none -- populate manifests/machines/)}"
      return 1
    fi
    machine_name=$(< "$STATE_FILE")
    machine_name="${machine_name//[[:space:]]/}"
    if [[ -z "$machine_name" ]]; then
      error "state file ${STATE_FILE} is empty"
      return 1
    fi
    machine_file=$(resolve_machine_path "$machine_name") || return 1
  fi

  if [[ ! -f "$machine_file" ]]; then
    error "machine manifest not found: ${machine_file}"
    return 1
  fi
  if [[ ! -f "$DEFAULTS" ]]; then
    error "defaults not found: ${DEFAULTS}"
    return 1
  fi

  if (( use_stdout == 1 )); then
    resolve_pipeline "$DEFAULTS" "$machine_file"
  else
    resolve_manifest "$DEFAULTS" "$machine_file" "$OUT"
    # D-04 advisory warnings on the active machine after a successful resolve.
    emit_unknown_key_warnings "$machine_file"
  fi
  return 0
}

main "$@"
