#!/bin/zsh

# =============================================================================
# install/resolver.zsh -- compile a v2 machine manifest into resolved.json
#
# Purpose:      Validate a machine manifest (manifests/machines/<name>.toml)
#               against the feature registry (manifests/features.toml) and the
#               bundle set (manifests/bundles/), then compile it into
#               $XDG_STATE_HOME/dotfiles/resolved.json (or stdout).
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh (>= 5); install/messages.zsh.
# Side effects: writes $XDG_STATE_HOME/dotfiles/resolved.json (atomic via
#               mktemp + mv); emits stderr errors for invalid manifests.
# =============================================================================

set -euo pipefail

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task manifest:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# REGISTRY and SHARED_DIR are overridable via --registry and --shared-dir CLI
# flags (testing only -- see main() arg parser). The runtime values are the
# only ones referenced by validate_manifest / resolve_pipeline; the initial
# assignment here is the production default.
typeset REGISTRY="${DOTFILEDIR}/manifests/features.toml"
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

# Path-component regex for every TOML-sourced name concatenated into a
# filesystem path (bundle names, identity value, claude addon names). Only
# the machine name was guarded before; a value like "../evil" would otherwise
# resolve a path outside its intended directory.
typeset -r PATH_NAME_RE='^[a-z0-9_][a-z0-9_-]*$'

# Package-name allow-list. Package names flow verbatim into the generated
# Brewfile (Ruby DSL, executed by `brew bundle`); a name containing a quote,
# backtick, `#`, or newline could break out of the emitted string literal and
# execute as Ruby. This admits every real Homebrew/vscode/cargo/uv/npm id
# character and nothing that can escape a single-quoted Ruby string.
typeset -r PACKAGE_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._@+/-]*$'

# Identity capability sentinels. An identity overlay that carries one of these
# comments declares that a machine using it MUST enable the matching feature.
# Colocated declared metadata -- no central identity enum, and unlike sniffing
# the overlay's functional lines a sentinel cannot drift for an unrelated
# reason (a socket-path refactor, an Include split).
typeset -r SENTINEL_SSH='# capability: one-password-ssh'
typeset -r SENTINEL_SIGN='# capability: one-password-signing'

# Whitelisted key paths (exact or dotted-prefix). Any scalar leaf path in a
# machine manifest not covered here is an error -- v2 rejects unknown keys
# (resolver + manifests version together; there is no cross-version skew for
# warn-only forward-compat to serve).
typeset -ra ALLOWED_KEYS=(
  "schema_version"
  "machine.description"
  "machine.os"
  "machine.arch"
  "machine.identity"
  "features.enabled"
  "features.disabled"
  "packages.bundles"
  "packages.formulae"
  "packages.casks"
  "packages.mas"
  "packages.vscode"
  "packages.cargo"
  "packages.uv"
  "packages.npm"
  "claude.addons"
)

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

# read_nonempty_lines <arrayname>
# Read stdin into the named array (zsh dynamic scope -- the caller declares the
# `local -a`), skipping blank lines. Word-split-safe: the `while IFS= read -r`
# form, NOT `array=( $(...) )`.
read_nonempty_lines() {
  local __name="$1" __line
  local -a __acc=()
  while IFS= read -r __line; do
    [[ -z "$__line" ]] && continue
    __acc+=("$__line")
  done
  set -A "$__name" "${__acc[@]}"
}

# bundle_files_for <machine_file> <arrayname>
# Resolve the machine's packages.bundles list to shared-bundle TOML paths, in
# declared order. Sets the named array. Returns non-zero (with an error) if a
# bundle name is shape-invalid or missing -- callers must handle it.
bundle_files_for() {
  local machine_file="$1" __out="$2"
  local -a __names=() __paths=()
  read_nonempty_lines __names < <(yq -r '.packages.bundles[]?' "$machine_file" 2>/dev/null || true)
  local bn shared_toml
  for bn in "${__names[@]}"; do
    [[ -z "$bn" ]] && continue
    if ! [[ "$bn" =~ $PATH_NAME_RE ]]; then
      error "invalid bundle name '${bn}' (must match ${PATH_NAME_RE}; path-traversal guard)"
      return 1
    fi
    shared_toml="${SHARED_DIR}/${bn}.toml"
    if [[ ! -f "$shared_toml" ]]; then
      error "bundle '${bn}' has no file at ${shared_toml}"
      return 1
    fi
    __paths+=("$shared_toml")
  done
  set -A "$__out" "${__paths[@]}"
}

# validate_manifest <machine_file>
# Returns the error count via the global VALIDATE_ERRORS and exit status 0/1
# -- NOT via stdout (stdout capture is brittle: a stray echo would corrupt it).
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

  local grep_cmd="grep"
  command -v ggrep >/dev/null 2>&1 && grep_cmd="ggrep"

  # schema_version must be present and equal 2.
  local schema_value
  schema_value=$(yq -r '.schema_version // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$schema_value" ]]; then
    error "missing required field: schema_version (must equal 2)"
    errors=$(( errors + 1 ))
  elif [[ "$schema_value" != "2" ]]; then
    error "schema_version must equal 2; got: ${schema_value}"
    errors=$(( errors + 1 ))
  fi

  # machine.description must be present and non-empty.
  local desc
  desc=$(yq -r '.machine.description // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$desc" || "$desc" == "null" ]]; then
    error "missing required field: machine.description"
    errors=$(( errors + 1 ))
  fi

  # machine.os must be present and in {darwin, linux}.
  local os_value
  os_value=$(yq -r '.machine.os // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$os_value" ]]; then
    error "missing required field: machine.os (must be darwin or linux)"
    errors=$(( errors + 1 ))
  elif [[ "$os_value" != "darwin" && "$os_value" != "linux" ]]; then
    error "machine.os must be \"darwin\" or \"linux\"; got: ${os_value}"
    errors=$(( errors + 1 ))
  fi

  # machine.arch optional; if present must be arm64 or x86_64.
  local arch_value
  arch_value=$(yq -r '.machine.arch // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -n "$arch_value" && "$arch_value" != "arm64" && "$arch_value" != "x86_64" ]]; then
    error "machine.arch must be \"arm64\" or \"x86_64\" when present; got: ${arch_value}"
    errors=$(( errors + 1 ))
  fi

  # machine.identity: shape-guard, then overlay files must exist for git+ssh.
  local ident_val
  ident_val=$(yq -r '.machine.identity // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$ident_val" ]]; then
    error "missing required field: machine.identity"
    errors=$(( errors + 1 ))
  elif ! [[ "$ident_val" =~ $PATH_NAME_RE ]]; then
    error "invalid machine.identity '${ident_val}' (must match ${PATH_NAME_RE}; path-traversal guard)"
    errors=$(( errors + 1 ))
  else
    local ident_kind ident_dir ident_file valid
    for ident_kind in git ssh; do
      ident_dir="${DOTFILEDIR}/identity/${ident_kind}/identities"
      ident_file="${ident_dir}/${ident_val}"
      if [[ ! -f "$ident_file" ]]; then
        valid=$(print -l "$ident_dir"/*(N:t) 2>/dev/null | tr '\n' '|' | sed 's/|$//')
        error "machine.identity = '${ident_val}' has no ${ident_kind} overlay at ${ident_file} (available: ${valid:-<none>})"
        errors=$(( errors + 1 ))
      fi
    done
  fi

  # [features] table must exist; enabled + disabled must be arrays.
  local features_present enabled_json disabled_json
  features_present=$(yq '. | has("features")' "$machine_file" 2>/dev/null || echo false)
  if [[ "$features_present" != "true" ]]; then
    error "missing required table: [features] (with enabled and disabled arrays)"
    errors=$(( errors + 1 ))
    enabled_json='[]'
    disabled_json='[]'
  else
    local en_tag dis_tag
    en_tag=$(yq '.features.enabled | tag' "$machine_file" 2>/dev/null || echo "")
    dis_tag=$(yq '.features.disabled | tag' "$machine_file" 2>/dev/null || echo "")
    if [[ "$en_tag" != "!!seq" ]]; then
      error "features.enabled must be an array; got tag: ${en_tag:-<missing>}"
      errors=$(( errors + 1 ))
    fi
    if [[ "$dis_tag" != "!!seq" ]]; then
      error "features.disabled must be an array; got tag: ${dis_tag:-<missing>}"
      errors=$(( errors + 1 ))
    fi
    enabled_json=$(yq -o=json '.features.enabled // []' "$machine_file" 2>/dev/null || echo '[]')
    disabled_json=$(yq -o=json '.features.disabled // []' "$machine_file" 2>/dev/null || echo '[]')
  fi

  # Feature accounting against the registry. One line per violation.
  if [[ ! -f "$REGISTRY" ]]; then
    error "feature registry not found: ${REGISTRY}"
    errors=$(( errors + 1 ))
  else
    local registry_json accounting
    registry_json=$(yq -o=json '.' "$REGISTRY" 2>/dev/null || echo '{}')
    [[ -z "$registry_json" || "$registry_json" == "null" ]] && registry_json='{}'
    accounting=$(jq -rn \
      --arg os "$os_value" \
      --argjson reg "$registry_json" \
      --argjson en "$enabled_json" \
      --argjson dis "$disabled_json" '
      ($reg | to_entries | map({
        key,
        applicable: ((.value.platforms // null) as $p
                     | if $p == null then true else ($p | index($os) != null) end)
      })) as $flags
      | ($flags | map(.key)) as $all
      | ($flags | map(select(.applicable) | .key)) as $applicable
      | ($flags | map(select(.applicable | not) | .key)) as $inapplicable
      | [
          (($en + $dis) | map(select(. as $n | ($all | index($n)) == null)) | unique
             | map("unknown feature (not in registry): \(.)")),
          ($en | map(select(. as $n | $dis | index($n) != null)) | unique
             | map("feature in both enabled and disabled: \(.)")),
          ($en | group_by(.) | map(select(length > 1) | .[0]) | map("duplicate in enabled: \(.)")),
          ($dis | group_by(.) | map(select(length > 1) | .[0]) | map("duplicate in disabled: \(.)")),
          (($en + $dis) | map(select(. as $n | $inapplicable | index($n) != null)) | unique
             | map("feature inapplicable on os=\($os) but listed (remove it): \(.)")),
          ($applicable | map(select(. as $n | (($en + $dis) | index($n)) == null))
             | map("unaccounted feature (add to features.enabled or features.disabled): \(.)"))
        ] | add | .[]' 2>/dev/null || true)
    if [[ -n "$accounting" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        error "$line"
        errors=$(( errors + 1 ))
      done <<< "$accounting"
    fi
  fi

  # Identity/1Password sentinel consistency.
  if [[ -n "$ident_val" && "$ident_val" =~ $PATH_NAME_RE ]]; then
    local ssh_overlay git_overlay en_has_ssh en_has_sign
    ssh_overlay="${DOTFILEDIR}/identity/ssh/identities/${ident_val}"
    git_overlay="${DOTFILEDIR}/identity/git/identities/${ident_val}"
    en_has_ssh=$(printf '%s' "$enabled_json" | jq -r 'index("one-password-ssh") != null')
    en_has_sign=$(printf '%s' "$enabled_json" | jq -r 'index("one-password-signing") != null')
    if [[ -f "$ssh_overlay" ]] && "$grep_cmd" -qF "$SENTINEL_SSH" "$ssh_overlay" && [[ "$en_has_ssh" != "true" ]]; then
      error "identity '${ident_val}' declares one-password-ssh capability -- features.enabled must include one-password-ssh"
      errors=$(( errors + 1 ))
    fi
    if [[ -f "$git_overlay" ]] && "$grep_cmd" -qF "$SENTINEL_SIGN" "$git_overlay" && [[ "$en_has_sign" != "true" ]]; then
      error "identity '${ident_val}' declares one-password-signing capability -- features.enabled must include one-password-signing"
      errors=$(( errors + 1 ))
    fi
  fi

  # packages.bundles: non-empty !!seq containing "dotfiles"; each name valid +
  # present as a bundle file; bundle platforms (when declared) include os.
  local bundles_present bundles_tag bundles_length contains_dotfiles
  bundles_present=$(yq '.packages | has("bundles")' "$machine_file" 2>/dev/null || echo false)
  if [[ "$bundles_present" != "true" ]]; then
    error "missing required field: packages.bundles"
    errors=$(( errors + 1 ))
  else
    bundles_tag=$(yq '.packages.bundles | tag' "$machine_file" 2>/dev/null || echo "")
    if [[ "$bundles_tag" != "!!seq" ]]; then
      error "packages.bundles must be an array; got tag: ${bundles_tag}"
      errors=$(( errors + 1 ))
    else
      bundles_length=$(yq '.packages.bundles | length' "$machine_file" 2>/dev/null || echo 0)
      if (( bundles_length < 1 )); then
        error "packages.bundles must contain at least one bundle"
        errors=$(( errors + 1 ))
      fi
      contains_dotfiles=$(yq '.packages.bundles | contains(["dotfiles"])' "$machine_file" 2>/dev/null || echo false)
      if [[ "$contains_dotfiles" != "true" ]]; then
        error 'packages.bundles must include "dotfiles"'
        errors=$(( errors + 1 ))
      fi
      local -a bundle_names=()
      read_nonempty_lines bundle_names < <(yq -r '.packages.bundles[]' "$machine_file" 2>/dev/null || true)
      local bn shared_toml available bundle_platforms
      for bn in "${bundle_names[@]}"; do
        [[ -z "$bn" ]] && continue
        if ! [[ "$bn" =~ $PATH_NAME_RE ]]; then
          error "invalid bundle name '${bn}' (must match ${PATH_NAME_RE}; path-traversal guard)"
          errors=$(( errors + 1 ))
          continue
        fi
        shared_toml="${SHARED_DIR}/${bn}.toml"
        if [[ ! -f "$shared_toml" ]]; then
          available=$(print -l "${SHARED_DIR}"/*.toml(N:t:r) 2>/dev/null | tr '\n' '|' | sed 's/|$//')
          error "packages.bundles entry '${bn}' has no file at ${shared_toml} (available: ${available:-<none>})"
          errors=$(( errors + 1 ))
          continue
        fi
        bundle_platforms=$(yq -o=json '.platforms // "any"' "$shared_toml" 2>/dev/null || echo '"any"')
        if [[ "$bundle_platforms" != '"any"' ]]; then
          local ok
          ok=$(printf '%s' "$bundle_platforms" | jq -r --arg os "$os_value" 'index($os) != null')
          if [[ "$ok" != "true" ]]; then
            error "bundle '${bn}' is not available on os=${os_value} (platforms: ${bundle_platforms})"
            errors=$(( errors + 1 ))
          fi
        fi
      done
    fi
  fi

  # packages.* buckets: bare-string arrays except mas ({ id, name } objects).
  local bad_shape
  bad_shape=$(jq -rn --argjson p "$(yq -o=json '.packages // {}' "$machine_file" 2>/dev/null || echo '{}')" '
    [ "formulae", "casks", "vscode", "cargo", "npm", "uv" ] as $bare
    | ( $bare | map(. as $k | ($p[$k] // []) | map(select(type != "string")) | length > 0 | select(.) | $k) )
    + ( ($p.mas // []) | map(select((.id | type) != "number" or (.name | type) != "string")) | if length > 0 then ["mas"] else [] end )
    | .[]' 2>/dev/null || true)
  if [[ -n "$bad_shape" ]]; then
    while IFS= read -r bkt; do
      [[ -z "$bkt" ]] && continue
      if [[ "$bkt" == "mas" ]]; then
        error "packages.mas entries must be { id = <number>, name = <string> } objects"
      else
        error "packages.${bkt} entries must be bare strings"
      fi
      errors=$(( errors + 1 ))
    done <<< "$bad_shape"
  fi

  # claude.addons: shape-guard + existence.
  local addons_json addon
  addons_json=$(yq -o=json '.claude.addons // []' "$machine_file" 2>/dev/null || echo '[]')
  while IFS= read -r addon; do
    [[ -z "$addon" ]] && continue
    if ! [[ "$addon" =~ $PATH_NAME_RE ]]; then
      error "invalid claude addon name '${addon}' (must match ${PATH_NAME_RE}; path-traversal guard)"
      errors=$(( errors + 1 ))
      continue
    fi
    if [[ ! -f "${DOTFILEDIR}/manifests/claude-addons/${addon}.toml" ]]; then
      error "claude.addons references unknown addon \"${addon}\" -- no manifests/claude-addons/${addon}.toml"
      errors=$(( errors + 1 ))
    fi
  done < <(echo "$addons_json" | jq -r '.[]')

  # Unknown keys are errors. Walk every scalar leaf path and reject any not
  # covered by the whitelist (exact match or dotted-prefix).
  local found matched expected
  while IFS= read -r found; do
    [[ -z "$found" ]] && continue
    matched=0
    for expected in "${ALLOWED_KEYS[@]}"; do
      if [[ "$found" == "$expected" ]] || [[ "$found" == "${expected}."* ]]; then
        matched=1
        break
      fi
    done
    if (( matched == 0 )); then
      error "unknown key: ${found}"
      errors=$(( errors + 1 ))
    fi
  done < <(yq -o json "$machine_file" 2>/dev/null \
            | jq -r '[paths(scalars) | join(".")] | .[]' 2>/dev/null || true)

  VALIDATE_ERRORS=$errors
  if (( errors > 0 )); then
    return 1
  fi
  return 0
}

# union_bucket <machine_file> <key> <finalize_jq> <bundle_file...>
# Concatenate the .packages.<key> arrays from each bundle (declared order) then
# the machine, and apply the finalize jq expression. Bare-string buckets use
# `add | unique`; casks wrap to { name } objects; mas dedupes by .id (last
# wins, so the machine overrides a bundle).
union_bucket() {
  local machine_file="$1" key="$2" finalize="$3"
  shift 3
  {
    local f
    for f in "$@"; do
      yq -o=json ".packages.${key} // []" "$f"
    done
    yq -o=json ".packages.${key} // []" "$machine_file"
  } | jq -s "$finalize"
}

# resolve_pipeline <machine_file>
# Validate-free compile: read the v2 manifest + registry + bundles and emit the
# v1 resolved.json contract (minus schema_version, which nothing consumes) to
# stdout. Callers validate first (main() does); resolve_pipeline trusts input.
resolve_pipeline() {
  local machine_file="$1"

  local desc os arch ident
  desc=$(yq -r '.machine.description' "$machine_file")
  os=$(yq -r '.machine.os' "$machine_file")
  arch=$(yq -r '.machine.arch // ""' "$machine_file")
  [[ -z "$arch" ]] && arch=$(uname -m)
  ident=$(yq -r '.machine.identity' "$machine_file")

  # features boolean map: every registry flag -> (name in enabled).
  local registry_keys enabled_json features_map
  registry_keys=$(yq -o=json 'keys' "$REGISTRY" 2>/dev/null || echo '[]')
  [[ -z "$registry_keys" || "$registry_keys" == "null" ]] && registry_keys='[]'
  enabled_json=$(yq -o=json '.features.enabled // []' "$machine_file")
  features_map=$(jq -n --argjson keys "$registry_keys" --argjson en "$enabled_json" '
    reduce $keys[] as $k ({}; .[$k] = ($en | index($k) != null))')

  # bundles list (declared order) + their file paths.
  local bundles_json
  bundles_json=$(yq -o=json '.packages.bundles // []' "$machine_file")
  local -a bundle_files=()
  bundle_files_for "$machine_file" bundle_files || return 1

  # Per-bucket union across bundles + machine.
  local union_formulae union_casks union_mas union_vscode union_cargo union_uv union_npm
  union_formulae=$(union_bucket "$machine_file" formulae 'add | unique' "${bundle_files[@]}")
  union_casks=$(union_bucket    "$machine_file" casks    'add | unique | map({ name: . })' "${bundle_files[@]}")
  union_mas=$(union_bucket      "$machine_file" mas      'add | group_by(.id) | map(.[-1])' "${bundle_files[@]}")
  union_vscode=$(union_bucket   "$machine_file" vscode   'add | unique' "${bundle_files[@]}")
  union_cargo=$(union_bucket    "$machine_file" cargo    'add | unique' "${bundle_files[@]}")
  union_uv=$(union_bucket       "$machine_file" uv       'add | unique' "${bundle_files[@]}")
  union_npm=$(union_bucket      "$machine_file" npm      'add | unique' "${bundle_files[@]}")

  # Security: every package name reaches the generated Brewfile verbatim (Ruby
  # DSL, executed by `brew bundle`). A name containing a quote/backtick/#/
  # newline would escape the emitted single-quoted string and run as Ruby.
  # Validate the fully-unioned set and fail closed. mas.id must be numeric so
  # the unquoted `id:` emit cannot carry a string payload.
  local invalid_names bad_ids
  invalid_names=$(jq -rn \
    --argjson f "$union_formulae" --argjson c "$union_casks" \
    --argjson v "$union_vscode" --argjson cr "$union_cargo" \
    --argjson u "$union_uv" --argjson n "$union_npm" --argjson m "$union_mas" \
    '($f + $v + $cr + $u + $n + ($c | map(.name)) + ($m | map(.name)))
     | map(select(test("'"$PACKAGE_NAME_RE"'") | not)) | .[]' 2>/dev/null || true)
  if [[ -n "$invalid_names" ]]; then
    error "invalid package name(s) -- must match ${PACKAGE_NAME_RE}:"
    printf '%s\n' "$invalid_names" | while IFS= read -r b; do error "  ${b}"; done
    return 1
  fi
  bad_ids=$(jq -rn --argjson m "$union_mas" \
    '$m | map(select((.id | type) != "number") | (.name // "<unnamed>")) | .[]' 2>/dev/null || true)
  if [[ -n "$bad_ids" ]]; then
    error "mas entry id must be a JSON number; offending entries: ${bad_ids}"
    return 1
  fi

  local addons_json
  addons_json=$(yq -o=json '.claude.addons // []' "$machine_file")

  # Assemble the resolved.json contract. schema_version is intentionally
  # omitted -- nothing consumes it. packages.brew.{formulae,casks,mas} hold
  # the full brew package set (bundle union + machine inline); packages.brew
  # .bundles is the selection trace.
  jq -n \
    --arg desc "$desc" --arg os "$os" --arg arch "$arch" --arg ident "$ident" \
    --argjson features "$features_map" \
    --argjson bundles "$bundles_json" \
    --argjson formulae "$union_formulae" --argjson casks "$union_casks" --argjson mas "$union_mas" \
    --argjson vscode "$union_vscode" --argjson cargo "$union_cargo" \
    --argjson uv "$union_uv" --argjson npm "$union_npm" \
    --argjson addons "$addons_json" '
    {
      meta: { description: $desc },
      platform: { os: $os, arch: $arch },
      features: $features,
      identity: { git: $ident, ssh: $ident },
      packages: {
        brew: {
          bundles: $bundles,
          formulae: $formulae,
          casks: $casks,
          mas: $mas
        },
        vscode: { extensions: $vscode },
        cargo: { crates: $cargo },
        uv: { tools: $uv },
        npm: { packages: $npm }
      },
      claude: { addons: $addons }
    }'
}

# resolve_manifest <machine_path> <out_path>
# mktemp + mv so readers never see a partial file.
resolve_manifest() {
  local machine_path="$1" out_path="$2"
  local out_dir tmp
  out_dir="${out_path:h}"
  mkdir -p "$out_dir"
  tmp=$(mktemp "${out_path}.XXXXXX")
  trap 'rm -f "$tmp"' EXIT INT TERM
  {
    resolve_pipeline "$machine_path" > "$tmp"
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
# guard), then build the canonical manifest path.
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
  echo "${MACHINES_DIR}/${name}.toml"
}

main() {
  local mode="resolve"
  local machine_arg=""
  local use_stdout=0

  while (( $# > 0 )); do
    case "$1" in
      --validate-only)
        mode="validate"; shift ;;
      --machine)
        if (( $# < 2 )); then error "--machine requires an argument"; return 1; fi
        machine_arg="$2"; shift 2 ;;
      --stdout)
        use_stdout=1; shift ;;
      --registry)
        # Testing only: override path to features.toml.
        if (( $# < 2 )); then error "--registry requires an argument"; return 1; fi
        REGISTRY="$2"; shift 2 ;;
      --shared-dir)
        # Testing only: override path to manifests/bundles/ directory.
        if (( $# < 2 )); then error "--shared-dir requires an argument"; return 1; fi
        SHARED_DIR="$2"; shift 2 ;;
      --help|-h)
        cat <<'USAGE'
Usage:
  zsh install/resolver.zsh                              # resolve mode (default)
  zsh install/resolver.zsh --validate-only --machine <name>
  zsh install/resolver.zsh --machine <name> --stdout    # ad-hoc resolve to stdout

Test-only flags (do not use in production):
  --registry <path>       override features.toml path
  --shared-dir <path>     override manifests/bundles/ directory

Environment:
  DOTFILEDIR        repo root (required)
  XDG_STATE_HOME    state directory (default: $HOME/.local/state)
USAGE
        return 0 ;;
      *)
        error "unknown argument: $1"; return 1 ;;
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
    validate_manifest "$machine_file" || true
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
  if [[ ! -f "$REGISTRY" ]]; then
    error "feature registry not found: ${REGISTRY}"
    return 1
  fi

  # Fail closed: resolve must never emit resolved.json from an invalid manifest.
  validate_manifest "$machine_file" || true
  if (( VALIDATE_ERRORS > 0 )); then
    error "validation failed for ${machine_name}: ${VALIDATE_ERRORS} error(s)"
    return 1
  fi

  if (( use_stdout == 1 )); then
    resolve_pipeline "$machine_file"
  else
    resolve_manifest "$machine_file" "$OUT"
  fi
  return 0
}

main "$@"
