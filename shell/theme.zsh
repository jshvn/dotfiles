#!/bin/zsh

# =============================================================================
# shell/theme.zsh -- prompt + syntax-highlight + man-page + grc colour setup
#
# Purpose:      Customize PROMPT / RPROMPT (alanpeabody-derived); set
#               highlight + man + grc colours.
# Depends on:   OMZ git_prompt_status / git_prompt_info (sourced via
#               antidote in .zshrc); eza, highlight, grc on PATH.
# Side effects: sets EZA_CONFIG_HOME; unsets LS_COLORS; sets PROMPT,
#               RPROMPT, ZSH_THEME_GIT_PROMPT_*; defines highlight alias;
#               redefines man() with LESS_TERMCAP_* colour env; aliases
#               supported commands through `grc --colour=auto`.
# =============================================================================

export EZA_CONFIG_HOME="$XDG_CONFIG_HOME/eza"
unset LS_COLORS

# Native zsh prompt escapes (%F{color}...%f) for reliable width calculation.
local user='%F{green}%n@%m%f'
local pwd='%F{blue}%~%f'
local return_code='%(?..%F{red}%? ↵%f)'
local git_branch='$(git_prompt_status)%f$(git_prompt_info)%f'
local time='%F{cyan}%T%f'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{green}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{cyan} ✭"
ZSH_THEME_GIT_PROMPT_ADDED="%F{green} ✚"
ZSH_THEME_GIT_PROMPT_MODIFIED="%F{blue} ✹"
ZSH_THEME_GIT_PROMPT_RENAMED="%F{magenta} ➜"
ZSH_THEME_GIT_PROMPT_DELETED="%F{red} ✖"
ZSH_THEME_GIT_PROMPT_UNMERGED="%F{yellow} ═"
ZSH_THEME_GIT_PROMPT_AHEAD="%F{green} ↑"
ZSH_THEME_GIT_PROMPT_BEHIND="%F{red} ↓"
ZSH_THEME_GIT_PROMPT_DIVERGED="%F{yellow} ↕"
ZSH_THEME_GIT_PROMPT_STASHED="%F{blue} ⚑"

PROMPT="${user}:${pwd}$ "
RPROMPT="${return_code} ${git_branch} ${time}"

alias highlight="highlight --out-format=xterm256 --style=duotone-dark-sky"

# Colourise man pages. LESS_TERMCAP_* reference:
# https://unix.stackexchange.com/questions/108699
man() {
  env \
    LESS_TERMCAP_mb=$(printf "\e[1;34m") \
    LESS_TERMCAP_md=$(printf "\e[1;34m") \
    LESS_TERMCAP_me=$(printf "\e[0m") \
    LESS_TERMCAP_se=$(printf "\e[0m") \
    LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
    LESS_TERMCAP_ue=$(printf "\e[0m") \
    LESS_TERMCAP_us=$(printf "\e[1;32m") \
    man "$@"
}

if [[ "$TERM" != dumb ]] && (( $+commands[grc] )) ; then
  cmds=(
    df \
    diff \
    dig \
    env \
    id \
    ifconfig \
    kubectl \
    netstat \
    ping \
    ping6 \
    ps \
    uptime \
  );

  for cmd in $cmds ; do
    if (( $+commands[$cmd] )) ; then
      alias $cmd="grc --colour=auto $(whence $cmd)"
    fi
  done

  unset cmds cmd
fi
