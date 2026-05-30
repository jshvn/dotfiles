#!/bin/zsh

# =============================================================================
# install/resolver.zsh -- compile defaults + machine manifest into resolved.json
#
# Purpose:      Validate + deep-merge manifests/defaults.toml with the active
#               machine's manifests/machines/<name>.toml, then atomically
#               write the result to $XDG_STATE_HOME/dotfiles/resolved.json
#               (or stdout).
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh (>= 5); install/messages.zsh.
# Side effects: writes $XDG_STATE_HOME/dotfiles/resolved.json (atomic via
#               mktemp + mv); emits stderr warnings for unknown manifest keys.
# =============================================================================

set -euo pipefail

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task manifest:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# DEFAULTS and SHARED_DIR are overridable via --defaults and --shared-dir
# CLI flags (testing only -- see main() arg parser). The runtime values are
# the only ones referenced by validate_manifest / resolve_pipeline; the
# initial assignment here is the production default.
typeset DEFAULTS="${DOTFILEDIR}/manifests/defaults.toml"
typeset SHARED_DIR="${DOTFILEDIR}/manifests/bundles"
typeset -r MACHINES_DIR="${DOTFILEDIR}/manifests/machines"
typeset -r STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -r STATE_FILE="${STATE_DIR}/machine"
typeset -r OUT="${STATE_DIR}/resolved.json"

# Machine-name regex: kebab-case identifier; the first character may also be
# an underscore so test/negative fixture names (e.g. _invalid-bad-os) are
# accepted by --validate-only. Path-traversal characters (`/`, `.`, `..`,
# spaces) remain rejected.
typeset -r MACHINE_NAME_RE='^[a-z0-9_][a-z0-9_-]*$'

list_available_machines() {
  local -a files
  files=("${MACHINES_DIR}"/*.toml(N))
  if (( ${#files} == 0 )); then
    echo ""
    return 0
  fi
  local f names=""
  for f in "${files[@]}"; do
    local base="${f:t:r}"
    names+="${base} "
  done
  echo "${names% }"
}

# validate_manifest <machine_file>
# Hand-rolled required-field + enum validator. Returns the error count via
# the global VALIDATE_ERRORS and exit status 0/1 -- NOT via stdout. Stdout
# capture is brittle: any future addition that writes to stdout (an unwrapped
# command, a stray echo) would corrupt the captured count.
typeset -gi VALIDATE_ERRORS=0
validate_manifest() {
  local machine_file="$1"
  VALIDATE_ERRORS=0
  local errors=0

  if [[ ! -f "$machine_file" ]]; then
    error "machine manifest not found: ${machine_file}"
    VALIDATE_ERRORS=1
    return 1
  fi

  # NOTE: the loop variable is `field_path`, NOT `path`. In zsh, `path` is a
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
      contains_core=$(yq '.packages.brew.bundles | contains(["dotfiles"])' "$machine_file" 2>/dev/null || echo false)
      if [[ "$contains_core" != "true" ]]; then
        error 'packages.brew.bundles must include "dotfiles"'
        errors=$(( errors + 1 ))
      fi
      # Each bundle name must resolve to a typed-bucket TOML under
      # manifests/bundles/. Catch typos at validate time (a missing bundle
      # file would silently contribute nothing to packages.brew.extra_packages
      # at resolve time, with no error).
      # Word-split-safe accumulation via `while IFS= read -r` -- NOT the
      # `array=( $(...) )` form (vulnerable to word-splitting; not
      # shellcheck-clean). See taskfiles/links.yml for the same rule.
      local -a bundle_names=()
      local _bn_line
      while IFS= read -r _bn_line; do
        [[ -z "$_bn_line" ]] && continue
        bundle_names+=("$_bn_line")
      done < <(yq -r '.packages.brew.bundles[]' "$machine_file" 2>/dev/null || true)
      local bn shared_toml available
      for bn in "${bundle_names[@]}"; do
        [[ -z "$bn" ]] && continue
        shared_toml="${SHARED_DIR}/${bn}.toml"
        if [[ ! -f "$shared_toml" ]]; then
          available=$(print -l "${SHARED_DIR}"/*.toml(N:t:r) 2>/dev/null | tr '\n' '|' | sed 's/|$//')
          error "packages.brew.bundles entry '${bn}' has no shared file at ${shared_toml} (available: ${available:-<none>})"
          errors=$(( errors + 1 ))
        fi
      done
    fi
  fi

  # platform.os must equal "darwin" (v1 macOS-only).
  local os_value
  os_value=$(yq -r '.platform.os // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -n "$os_value" ]] && [[ "$os_value" != "darwin" ]]; then
    error "platform.os must equal \"darwin\" in v1; got: ${os_value}"
    errors=$(( errors + 1 ))
  fi

  # schema_version must be present and equal 1. The entire v2 forward-compat
  # story depends on this field; without an explicit check, a v1 resolver
  # running against a v2 manifest would silently produce wrong output.
  local schema_value
  schema_value=$(yq -r '.schema_version // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$schema_value" ]]; then
    error "missing required field: schema_version (must equal 1)"
    errors=$(( errors + 1 ))
  elif [[ "$schema_value" != "1" ]]; then
    error "schema_version must equal 1 in v1 resolver; got: ${schema_value}"
    errors=$(( errors + 1 ))
  fi

  # identity.git / identity.ssh are filesystem-driven: the value must be the
  # basename of an existing overlay file under identity/<kind>/identities/.
  # Adding a new identity = drop the overlay files; no edits here. The valid
  # set is computed for the error message so the operator sees what's available.
  local ident_key ident_val ident_file ident_dir valid
  for ident_key in git ssh; do
    ident_val=$(yq -r ".identity.${ident_key} // \"\"" "$machine_file" 2>/dev/null || echo "")
    if [[ -z "$ident_val" ]]; then
      continue
    fi
    ident_dir="${DOTFILEDIR}/identity/${ident_key}/identities"
    ident_file="${ident_dir}/${ident_val}"
    if [[ ! -f "$ident_file" ]]; then
      valid=$(print -l "$ident_dir"/*(N:t) 2>/dev/null | tr '\n' '|' | sed 's/|$//')
      error "identity.${ident_key} = '${ident_val}' has no overlay file at ${ident_file} (available: ${valid:-<none>})"
      errors=$(( errors + 1 ))
    fi
  done

  # Cross-field rules (see CLAUDE.md §Manifests as source of truth):
  # identity.ssh in {personal, work} requires features.one-password-ssh = true;
  # identity.git in {personal, work} requires features.one-password-signing = true.
  local identity_ssh identity_git
  identity_ssh=$(yq -r '.identity.ssh // ""' "$machine_file" 2>/dev/null || echo "")
  identity_git=$(yq -r '.identity.git // ""' "$machine_file" 2>/dev/null || echo "")

  local opssh opsign
  opssh=$(yq -r '.features."one-password-ssh" // false' "$machine_file" 2>/dev/null || echo "false")
  opsign=$(yq -r '.features."one-password-signing" // false' "$machine_file" 2>/dev/null || echo "false")

  case "$identity_ssh" in
    personal|work)
      if [[ "$opssh" != "true" ]]; then
        error "identity.ssh = \"${identity_ssh}\" requires features.one-password-ssh = true"
        errors=$(( errors + 1 ))
      fi
      ;;
  esac

  case "$identity_git" in
    personal|work)
      if [[ "$opsign" != "true" ]]; then
        error "identity.git = \"${identity_git}\" requires features.one-password-signing = true"
        errors=$(( errors + 1 ))
      fi
      ;;
  esac

  # claude.addons cross-field rule: every name listed must have a matching
  # manifests/claude-addons/<name>.toml. Compute the merged value the same
  # way resolve_pipeline pass 1 does -- so the validator sees what install
  # will see, regardless of which file declares the array.
  local addons_json
  addons_json=$(yq -o=json eval-all '. as $i ireduce ({}; . * $i) | .claude.addons // []' \
                    "$DEFAULTS" "$machine_file" 2>/dev/null) || addons_json='[]'

  local addon
  while IFS= read -r addon; do
    [[ -z "$addon" ]] && continue
    if [[ ! -f "${DOTFILEDIR}/manifests/claude-addons/${addon}.toml" ]]; then
      error "claude.addons references unknown addon \"${addon}\" -- no manifests/claude-addons/${addon}.toml"
      errors=$(( errors + 1 ))
    fi
  done < <(echo "$addons_json" | jq -r '.[]')

  VALIDATE_ERRORS=$errors
  if (( errors > 0 )); then
    return 1
  fi
  return 0
}

# emit_unknown_key_warnings <machine_file>
# Emit `unknown key: <path> at <file>:<line>` warnings to stderr for any
# scalar leaf path not under the whitelist. Always exits 0 (advisory only).
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
    "packages.brew.extra_packages.formulae"
    "packages.brew.extra_packages.casks"
    "packages.brew.extra_packages.mas"
    "identity.git"
    "identity.ssh"
    "claude"
    "claude.addons"
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
      # Only attempt the line-number heuristic when the leaf is a strict
      # identifier (no quoted-key metacharacters). TOML permits keys like
      # "a.b" or "a*b" which, if substituted into a regex, would be
      # interpreted as metacharacters and yield a misleading line number.
      # The warning still fires regardless; only the line: hint is omitted
      # in the unsafe case.
      if [[ "$leaf" =~ ^[A-Za-z0-9_-]+$ ]]; then
        line_no=$("$grep_cmd" -n "^${leaf}[[:space:]]*=" "$machine_file" 2>/dev/null | head -1 | cut -d: -f1 || true)
      else
        line_no=""
      fi
      warn "unknown key: ${found} at ${machine_file}:${line_no:-?}"
    fi
  # `paths(scalars)` is a jq builtin -- mikefarah yq does NOT support it
  # (a prior all-yq pipeline silently failed via 2>/dev/null and emit_*
  # never warned about anything). Pipe TOML -> JSON via yq, then jq for
  # the path walk. Both stages must succeed; if jq fails on a malformed
  # TOML the loop iterates zero paths and the function exits 0 (advisory).
  done < <(yq -o json "$machine_file" 2>/dev/null \
            | jq -r '[paths(scalars) | join(".")] | .[]' 2>/dev/null || true)

  return 0
}

# resolve_pipeline <defaults_path> <machine_path>
# Three-pass merge: yq deep-merge + extra_packages union (with shared
# bundles folded in) + arch backfill. Emits the final JSON to stdout.
#
# Pass 2 typed-bucket path concatenates source arrays in this order, then
# dedupes (last-write-wins):
#   1. defaults.toml             .packages.brew.extra_packages.{formulae,casks,mas}
#   2. manifests/bundles/<b>.toml .packages.brew.{formulae,casks,mas}
#      -- one entry per <b> in the merged packages.brew.bundles array.
#   3. machine.toml              .packages.brew.extra_packages.{formulae,casks,mas}
#
# Pass 2 uses the typed-bucket `extra_packages` shape:
#
#     [packages.brew.extra_packages]
#     formulae = [ "hugo" | { name, verify } ... ]
#     casks    = [ { name } ... ]
#     mas      = [ { id, name } ... ]
#
#     Per-sub-array dedupe rules:
#       formulae -- string-value for bare strings; .name for objects; if a
#                   bare and an object share the same name, the object wins
#                   (carries verify metadata).
#       casks    -- .name. Machine wins on conflict (last-write-wins).
#       mas      -- .id. Machine wins on conflict.
resolve_pipeline() {
  local defaults_path="$1"
  local machine_path="$2"

  # Pass 1: yq deep-merge with `. * .` (REPLACE arrays, deep-merge maps).
  local merged
  merged=$(yq eval-all '. as $i ireduce ({}; . * $i)' "$defaults_path" "$machine_path" -o json)

  # Pass 2: union + dedupe the typed extra_packages buckets from both sides.
  #
  # Typed-bucket path: one sub-array per kind. Each sub-array is unioned
  # independently with semantics tailored to its entry shape; see the
  # function-header comment.
  #
  # Source order (concatenated then deduped; last write wins):
  #   1. defaults.toml          .packages.brew.extra_packages.{formulae,casks,mas}
  #   2. manifests/bundles/<b>.toml .packages.brew.{formulae,casks,mas}
  #      for each <b> in the merged packages.brew.bundles array, in array
  #      order. (yq `. * .` REPLACES arrays, so merged.bundles == machine's
  #      bundles list. The machine drives bundle selection.)
  #   3. machine.toml           .packages.brew.extra_packages.{formulae,casks,mas}
  #
  # A missing bundle file is a hard error: the operator typoed a bundle name
  # and would otherwise silently lose every package in that bundle.
  # Word-split-safe accumulation (see the validate_manifest site above).
  local -a bundle_names=()
  local _bn_line
  while IFS= read -r _bn_line; do
    [[ -z "$_bn_line" ]] && continue
    bundle_names+=("$_bn_line")
  done < <(printf '%s' "$merged" | jq -r '.packages.brew.bundles[]?' 2>/dev/null || true)

  local def_formulae mach_formulae union_formulae
  local def_casks    mach_casks    union_casks
  local def_mas      mach_mas      union_mas

  def_formulae=$(yq -o=json  '.packages.brew.extra_packages.formulae // []' "$defaults_path")
  mach_formulae=$(yq -o=json '.packages.brew.extra_packages.formulae // []' "$machine_path")
  def_casks=$(yq -o=json  '.packages.brew.extra_packages.casks // []' "$defaults_path")
  mach_casks=$(yq -o=json '.packages.brew.extra_packages.casks // []' "$machine_path")
  def_mas=$(yq -o=json  '.packages.brew.extra_packages.mas // []' "$defaults_path")
  mach_mas=$(yq -o=json '.packages.brew.extra_packages.mas // []' "$machine_path")

  # Shared-bundle arrays gathered in declared order. Each bundle contributes
  # three JSON arrays (one per kind).
  local -a shared_formulae shared_casks shared_mas
  local bn shared_toml
  for bn in "${bundle_names[@]}"; do
    [[ -z "$bn" ]] && continue
    shared_toml="${SHARED_DIR}/${bn}.toml"
    if [[ ! -f "$shared_toml" ]]; then
      error "bundle '${bn}' referenced in packages.brew.bundles has no shared file at ${shared_toml}"
      return 1
    fi
    shared_formulae+=( "$(yq -o=json '.packages.brew.formulae // []' "$shared_toml")" )
    shared_casks+=(    "$(yq -o=json '.packages.brew.casks    // []' "$shared_toml")" )
    shared_mas+=(      "$(yq -o=json '.packages.brew.mas      // []' "$shared_toml")" )
  done

  # formulae dedupe: lift bare strings to { name: ., __bare: true }; group_by
  # .name; within each group prefer an object (drops __bare) over a bare
  # string; demote surviving __bare objects back to their string-name form.
  # jq -s slurps each source array as one list element; `add` flattens in
  # declaration order so the last collision wins.
  union_formulae=$(
    {
      print -r -- "$def_formulae"
      local sf
      for sf in "${shared_formulae[@]}"; do
        print -r -- "$sf"
      done
      print -r -- "$mach_formulae"
    } | jq -s '
        add
        | map(if type == "string" then { name: ., __bare: true } else . end)
        | group_by(.name)
        | map(if length == 1
              then .[0]
              else (map(select(.__bare | not)) | first // .[0])
              end)
        | map(if .__bare then .name else . end)
      '
  )

  union_casks=$(
    {
      print -r -- "$def_casks"
      local sc
      for sc in "${shared_casks[@]}"; do
        print -r -- "$sc"
      done
      print -r -- "$mach_casks"
    } | jq -s 'add | group_by(.name) | map(.[-1])'
  )

  union_mas=$(
    {
      print -r -- "$def_mas"
      local sm
      for sm in "${shared_mas[@]}"; do
        print -r -- "$sm"
      done
      print -r -- "$mach_mas"
    } | jq -s 'add | group_by(.id) | map(.[-1])'
  )

  local arch
  arch=$(yq -r '.platform.arch // ""' "$machine_path")
  if [[ -z "$arch" ]]; then
    arch=$(uname -m)
  fi

  printf '%s' "$merged" \
    | jq --argjson formulae "$union_formulae" \
         --argjson casks    "$union_casks" \
         --argjson mas      "$union_mas" \
         --arg     arch     "$arch" \
        '.packages.brew.extra_packages.formulae = $formulae
         | .packages.brew.extra_packages.casks  = $casks
         | .packages.brew.extra_packages.mas    = $mas
         | .platform.arch = $arch'
}

# resolve_manifest <defaults_path> <machine_path> <out_path>
# mktemp + mv so readers never see a partial file.
resolve_manifest() {
  local defaults_path="$1"
  local machine_path="$2"
  local out_path="$3"

  local out_dir tmp
  out_dir="${out_path:h}"
  mkdir -p "$out_dir"

  tmp=$(mktemp "${out_path}.XXXXXX")
  # Register a signal trap BEFORE the pipeline so Ctrl-C (SIGINT), SIGTERM,
  # or any other unhandled exit cleans up the tmp file. A `{ ... } || { rm
  # -f "$tmp"; ... }` would only handle ordinary command failures --
  # repeated Ctrl-Cs during iteration would otherwise accumulate
  # resolved.json.aBcDeF-style siblings. Clear the trap after a successful
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

# resolve_machine_path <machine_name>
# Validate the machine name against the kebab-case regex (path-traversal
# guard), build the canonical manifest path, and verify the resolved path
# equals the canonical form (no traversal).
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
  if [[ "$path" != "${MACHINES_DIR}/${name}.toml" ]]; then
    error "internal error: machine path mismatch for '${name}'"
    return 1
  fi
  echo "$path"
}

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
      --defaults)
        # Testing only: override path to defaults.toml.
        if (( $# < 2 )); then
          error "--defaults requires an argument"
          return 1
        fi
        DEFAULTS="$2"
        shift 2
        ;;
      --shared-dir)
        # Testing only: override path to manifests/bundles/ directory.
        if (( $# < 2 )); then
          error "--shared-dir requires an argument"
          return 1
        fi
        SHARED_DIR="$2"
        shift 2
        ;;
      --help|-h)
        cat <<'USAGE'
Usage:
  zsh install/resolver.zsh                              # resolve mode (default)
  zsh install/resolver.zsh --validate-only --machine <name>
  zsh install/resolver.zsh --machine <name> --stdout    # ad-hoc resolve to stdout

Test-only flags (do not use in production):
  --defaults <path>       override defaults.toml path
  --shared-dir <path>     override manifests/bundles/ directory

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
    # `|| true` keeps `set -e` from aborting on a non-zero return so we can
    # read the error count and emit a summary message.
    validate_manifest "$machine_file" || true
    emit_unknown_key_warnings "$machine_file"
    if (( VALIDATE_ERRORS > 0 )); then
      error "validation failed for ${machine_arg}: ${VALIDATE_ERRORS} error(s)"
      return 1
    fi
    return 0
  fi

  # Resolve mode.
  local machine_name machine_file
  if [[ -n "$machine_arg" ]]; then
    machine_name="$machine_arg"
    machine_file=$(resolve_machine_path "$machine_name") || return 1
  else
    if [[ ! -f "$STATE_FILE" ]]; then
      local available
      available=$(list_available_machines)
      error "no machine selected"
      error "  run: task setup -- <machine-name>"
      error "  available: ${available:-(none -- populate manifests/machines/)}"
      return 1
    fi
    # `read -r` trims only leading/trailing whitespace and stops at the
    # first newline. A prior `machine_name="${machine_name//[[:space:]]/}"`
    # stripped ALL whitespace (including embedded), so a state file
    # containing "bad name\n" would be silently rewritten to "badname",
    # which then either matched a real but unintended machine or failed the
    # regex check confusingly.
    machine_name=""
    read -r machine_name < "$STATE_FILE" || true
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
    emit_unknown_key_warnings "$machine_file"
  fi
  return 0
}

main "$@"
