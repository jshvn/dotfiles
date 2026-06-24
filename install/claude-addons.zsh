#!/bin/zsh

# =============================================================================
# install/claude-addons.zsh -- third-party Claude addon lifecycle
#
# Purpose:      Install, upgrade, remove, list, and validate Claude addons
#               declared in manifests/claude-addons/<name>.toml. The set of
#               addons enabled on the active machine is .claude.addons in
#               resolved.json.
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh (>= 5); install/messages.zsh.
# Side effects: runs each addon's [install].commands, writes/deletes
#               claude/settings.d/99-addon-<name>.json, removes addon-owned
#               files matching [footprint].file_globs + [footprint].extra_paths.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- invoke via taskfiles/claude-addons.yml}"
source "${DOTFILEDIR}/install/messages.zsh"

typeset -r ADDONS_DIR="${DOTFILEDIR}/manifests/claude-addons"
typeset -r SETTINGS_D="${DOTFILEDIR}/claude/settings.d"
typeset -r RESOLVED="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/resolved.json"
typeset -r XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

# _expand_path <raw> -- expand a fixed allow-list of location tokens WITHOUT
# eval. Mirrors the os/defaults narrow-substitution philosophy: never run
# command substitution, globbing, or word-splitting on TOML-supplied values.
_expand_path() {
  local p="$1"
  p="${p//\$\{HOME\}/$HOME}"
  p="${p//\$HOME/$HOME}"
  p="${p//\$\{XDG_CONFIG_HOME\}/${XDG_CONFIG_HOME:-$HOME/.config}}"
  p="${p//\$XDG_CONFIG_HOME/${XDG_CONFIG_HOME:-$HOME/.config}}"
  p="${p//\$\{XDG_DATA_HOME\}/${XDG_DATA_HOME:-$HOME/.local/share}}"
  p="${p//\$XDG_DATA_HOME/${XDG_DATA_HOME:-$HOME/.local/share}}"
  p="${p//\$\{XDG_STATE_HOME\}/${XDG_STATE_HOME:-$HOME/.local/state}}"
  p="${p//\$XDG_STATE_HOME/${XDG_STATE_HOME:-$HOME/.local/state}}"
  p="${p//\$\{XDG_CACHE_HOME\}/${XDG_CACHE_HOME:-$HOME/.cache}}"
  p="${p//\$XDG_CACHE_HOME/${XDG_CACHE_HOME:-$HOME/.cache}}"
  [[ "$p" == "~/"* ]] && p="${HOME}/${p#\~/}"
  [[ "$p" == "~" ]] && p="$HOME"
  printf '%s' "$p"
}

# is_addon_installed <toml_path> [allow_command=1]
# Returns 0 if [verify].path exists OR [verify].command exits 0. Path-based
# verify is eval-free (uses _expand_path). The command-based verify runs only
# when allow_command=1, so disabled addons never have their [verify].command
# executed (a merely-present TOML must not run arbitrary commands).
is_addon_installed() {
  local toml="$1" allow_command="${2:-1}"
  local verify_path verify_cmd expanded
  verify_path=$(yq -r '.verify.path // ""' "$toml")
  verify_cmd=$(yq -r '.verify.command // ""' "$toml")
  if [[ -n "$verify_path" ]]; then
    expanded=$(_expand_path "$verify_path")
    [[ -e "$expanded" ]] && return 0
    return 1
  fi
  if [[ -n "$verify_cmd" && "$allow_command" == "1" ]]; then
    # ponytail: eval of a TOML-supplied command. TRUST BOUNDARY: addon TOMLs
    # under manifests/claude-addons/ are operator-owned and reviewed at merge;
    # a malicious TOML here would be arbitrary code execution. Do not source
    # addon manifests from untrusted locations.
    eval "$verify_cmd" >/dev/null 2>&1
    return $?
  fi
  return 1
}

# enabled_addons
# Print enabled addons (one per line) from resolved.json.
enabled_addons() {
  jq -r '.claude.addons // [] | .[]' "$RESOLVED"
}

# is_enabled <name>
# Return 0 if <name> appears in .claude.addons.
is_enabled() {
  local name="$1" e
  for e in $(enabled_addons); do
    [[ "$e" == "$name" ]] && return 0
  done
  return 1
}

cmd_install() {
  local addons addon toml fragment jq_path cmd
  addons=$(enabled_addons)

  if [[ -z "$addons" ]]; then
    info "claude-addons: no enabled addons; nothing to install"
    return 0
  fi

  while IFS= read -r addon; do
    [[ -z "$addon" ]] && continue
    toml="${ADDONS_DIR}/${addon}.toml"
    if [[ ! -f "$toml" ]]; then
      cross "claude-addons: ${addon}: no manifest at ${toml}"
      return 1
    fi

    if is_addon_installed "$toml"; then
      if yq -e '.upgrade.commands' "$toml" >/dev/null 2>&1; then
        info "claude-addons: upgrading ${addon}"
        jq_path='.upgrade.commands[]'
      else
        check "claude-addons: ${addon} already installed (no upgrade defined)"
        jq_path=''
      fi
    else
      info "claude-addons: installing ${addon}"
      jq_path='.install.commands[]'
    fi

    if [[ -n "$jq_path" ]]; then
      while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue
        info "  > $cmd"
        # ponytail: eval of TOML-supplied install/upgrade commands -- same
        # operator-owned trust boundary as the verify eval above.
        eval "$cmd" || { cross "claude-addons: ${addon}: command failed: $cmd"; return 1; }
      done < <(yq -r "$jq_path" "$toml")
    fi

    fragment="${ADDONS_DIR}/${addon}.fragment.json"
    if [[ -f "$fragment" ]]; then
      mkdir -p "$SETTINGS_D"
      cp "$fragment" "${SETTINGS_D}/99-addon-${addon}.json"
      check "claude-addons: ${addon} fragment installed to settings.d/99-addon-${addon}.json"
    fi
  done <<< "$addons"

  success "claude-addons: install loop complete"
}

cmd_remove() {
  local name="$1"
  if [[ -z "$name" ]]; then
    cross "claude-addons:remove requires an addon name"
    return 1
  fi

  local toml="${ADDONS_DIR}/${name}.toml"
  if [[ ! -f "$toml" ]]; then
    cross "claude-addons: ${name}: no manifest at ${toml}"
    return 1
  fi

  # Phase 1: addon-defined remove commands (disarm self-healing hooks etc).
  if yq -e '.remove.commands' "$toml" >/dev/null 2>&1; then
    info "claude-addons: ${name}: running [remove].commands"
    local cmd
    while IFS= read -r cmd; do
      [[ -z "$cmd" ]] && continue
      info "  > $cmd"
      # ponytail: eval of TOML-supplied remove commands -- same operator-owned
      # trust boundary as the install/verify evals.
      eval "$cmd" || warn "  remove command failed (continuing): $cmd"
    done < <(yq -r '.remove.commands[]' "$toml")
  fi

  # Phase 2: footprint.file_globs relative to $XDG_CONFIG_HOME/claude/.
  setopt extended_glob null_glob
  local glob match
  while IFS= read -r glob; do
    [[ -z "$glob" ]] && continue
    # Path-safety: reject absolute and ../ traversal in file_globs.
    if [[ "$glob" == /* || "$glob" == *..* ]]; then
      cross "claude-addons: ${name}: unsafe glob in file_globs: $glob"
      return 1
    fi
    info "  rm -rf ${XDG_CONFIG}/claude/${glob}"
    for match in ${XDG_CONFIG}/claude/${~glob}; do
      [[ -e "$match" || -L "$match" ]] && rm -rf "$match"
    done
  done < <(yq -r '.footprint.file_globs[]' "$toml" 2>/dev/null)

  # Phase 3: footprint.extra_paths (absolute paths with env-var expansion).
  local raw_path expanded
  while IFS= read -r raw_path; do
    [[ -z "$raw_path" ]] && continue
    expanded=$(_expand_path "$raw_path")
    if [[ -e "$expanded" || -L "$expanded" ]]; then
      info "  rm -rf $expanded"
      rm -rf "$expanded"
    fi
  done < <(yq -r '.footprint.extra_paths[]' "$toml" 2>/dev/null)

  # Phase 4: delete addon's settings.d fragment if present.
  local fragment="${SETTINGS_D}/99-addon-${name}.json"
  if [[ -f "$fragment" ]]; then
    rm -f "$fragment"
    check "claude-addons: ${name} fragment removed from settings.d"
  fi

  success "claude-addons: ${name} removed"
}

cmd_list() {
  header "Claude addons"
  printf "  %-32s %-8s %-10s %s\n" "NAME" "ENABLED" "INSTALLED" "DESCRIPTION"

  local toml name desc enabled installed
  for toml in "${ADDONS_DIR}"/*.toml; do
    [[ -f "$toml" ]] || continue
    name=$(basename "$toml" .toml)
    desc=$(yq -r '.meta.description // ""' "$toml")

    enabled="no"
    if is_enabled "$name"; then enabled="yes"; fi

    # Only allow command-based verify for enabled addons; a disabled,
    # merely-present TOML must not have its [verify].command executed.
    installed="no"
    if is_addon_installed "$toml" "$([[ "$enabled" == "yes" ]] && echo 1 || echo 0)"; then
      installed="yes"
    fi

    printf "  %-32s %-8s %-10s %s\n" "$name" "$enabled" "$installed" "$desc"
  done
}

cmd_validate() {
  local rc=0
  local enabled_str
  enabled_str=$(enabled_addons | tr '\n' ' ')

  # Pass 1: every enabled addon has a matching TOML + passes [verify].
  local addon toml
  for addon in ${=enabled_str}; do
    toml="${ADDONS_DIR}/${addon}.toml"
    if [[ ! -f "$toml" ]]; then
      cross "claude-addons: ${addon} enabled but no manifest at ${toml}"
      rc=1
      continue
    fi
    if is_addon_installed "$toml"; then
      check "claude-addons: ${addon} installed"
    else
      cross "claude-addons: ${addon} enabled but [verify] failed -- run 'task claude-addons:install'"
      rc=1
    fi
  done

  # Pass 2: orphan detection -- for every TOML NOT in enabled, walk its
  # file_globs and extra_paths; warn if any matches exist.
  setopt extended_glob null_glob
  local name glob match raw_path expanded orphans
  for toml in "${ADDONS_DIR}"/*.toml; do
    [[ -f "$toml" ]] || continue
    name=$(basename "$toml" .toml)
    is_enabled "$name" && continue

    orphans=0
    while IFS= read -r glob; do
      [[ -z "$glob" ]] && continue
      for match in ${XDG_CONFIG}/claude/${~glob}; do
        [[ -e "$match" || -L "$match" ]] && orphans=$(( orphans + 1 ))
      done
    done < <(yq -r '.footprint.file_globs[]' "$toml" 2>/dev/null)

    while IFS= read -r raw_path; do
      [[ -z "$raw_path" ]] && continue
      expanded=$(_expand_path "$raw_path")
      [[ -e "$expanded" || -L "$expanded" ]] && orphans=$(( orphans + 1 ))
    done < <(yq -r '.footprint.extra_paths[]' "$toml" 2>/dev/null)

    if (( orphans > 0 )); then
      warn "claude-addons: ${name} disabled but ${orphans} orphan path(s) on disk -- run 'task claude-addons:remove -- ${name}'"
    fi
  done

  return $rc
}

# Subcommand dispatch.
sub="${1:-}"; shift 2>/dev/null || true
case "$sub" in
  install)  cmd_install ;;
  remove)   cmd_remove "${1:-}" ;;
  list)     cmd_list ;;
  validate) cmd_validate ;;
  *)
    cross "claude-addons.zsh: unknown subcommand '${sub}' (expected: install|remove|list|validate)"
    exit 2
    ;;
esac
