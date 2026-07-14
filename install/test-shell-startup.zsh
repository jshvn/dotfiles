#!/usr/bin/env zsh

# =============================================================================
# install/test-shell-startup.zsh -- smoke tests for zsh startup files
#
# Purpose:      Assert the interactive shell actually works: parse-check the
#               five startup files (lint:syntax only covers *.zsh, so .zshrc
#               et al. are otherwise never checked), verify a login
#               interactive shell exits 0, and assert the plugin-layer
#               markers theme.zsh depends on (prompt_subst, git_prompt_info/
#               status, `l` alias, extract, syntax highlighting,
#               autosuggestions) plus deferred compinit via a simulated
#               prompt (use-omz runs compinit from precmd).
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/messages.zsh; antidote + bundles installed
#               (task install).
# Side effects: spawns interactive zsh subshells (sources live .zshrc; may
#               write antidote static file / zcompdump caches).
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:shell-startup)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

# A fresh terminal never inherits FPATH; an exported FPATH from an old
# terminal would leak stale paths into the subshells below and fail
# autoloads. Test the canonical case.
unset FPATH

failed=0

# --- 1. Parse-check startup files (zsh -n reads but does not execute) -------
for f in .zshenv .zprofile .zshrc .zlogin .zlogout; do
    if zsh -n "${DOTFILEDIR}/shell/${f}" 2>/dev/null; then
        check "parse: shell/${f}"
    else
        cross "parse: shell/${f} has a syntax error"
        failed=$(( failed + 1 ))
    fi
done

# --- 2. Login interactive shell starts and exits cleanly --------------------
if zsh -lic exit >/dev/null 2>&1; then
    check "startup: zsh -lic exit returns 0"
else
    cross "startup: zsh -lic exit failed -- .zshrc is broken"
    failed=$(( failed + 1 ))
fi

# --- 3. Plugin-layer markers (all load synchronously in antidote load) ------
# One subshell, one assertion script: each marker echoes a token on success;
# compare the collected output against the full expected set.
markers=$(zsh -lic '
    [[ -o prompt_subst ]] && echo prompt_subst
    (( $+functions[git_prompt_info] )) && echo git_prompt_info
    (( $+functions[git_prompt_status] )) && echo git_prompt_status
    whence extract >/dev/null && echo extract
    [[ -n "${aliases[l]:-}" ]] && echo alias_l
    (( $+functions[_zsh_highlight] )) && echo highlight
    (( $+functions[_zsh_autosuggest_start] )) && echo autosuggest
' 2>/dev/null) || true

for marker in prompt_subst git_prompt_info git_prompt_status extract \
              alias_l highlight autosuggest; do
    if [[ "$markers" == *"$marker"* ]]; then
        check "marker: ${marker}"
    else
        cross "marker: ${marker} missing -- OMZ lib / plugin did not load"
        failed=$(( failed + 1 ))
    fi
done

# --- 4. Deferred compinit ran (use-omz flushes it from precmd) --------------
# `zsh -lic exit` never draws a prompt, so precmd never fires. Piping stdin
# to an interactive login shell DOES fire precmd before each read; after the
# first prompt, compdef must be a real function (the use-omz queue wrapper
# has been replaced) and _git must be registered as a completer.
compinit_markers=$(print -r -- '
    (( $+functions[compdef] )) && [[ "$(whence -v compdef)" != *"use-omz"* ]] && echo compdef_real
    [[ -n "${_comps[git]:-}" ]] && echo git_completion
    exit
' | zsh -li 2>/dev/null) || true

if [[ "$compinit_markers" == *compdef_real* ]]; then
    check "compinit: deferred compinit ran at first prompt"
else
    cross "compinit: compdef still the use-omz queue wrapper -- compinit never ran"
    failed=$(( failed + 1 ))
fi
if [[ "$compinit_markers" == *git_completion* ]]; then
    check "compinit: git completion registered"
else
    cross "compinit: _comps[git] missing -- completions not initialized"
    failed=$(( failed + 1 ))
fi

if (( failed == 0 )); then
    success "shell startup smoke tests passed"
else
    error "shell startup smoke tests: ${failed} failure(s)"
fi
exit "$failed"
