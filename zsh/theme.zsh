#!/bin/zsh

##############################
###### Prompt Customization
##############################

# set our ZSH theme customizations here
# the following prompt elements are based on the "alanpeabody" oh-my-zsh theme, but are
# customized to my liking and personal style. loosely based on ubuntu as well

# alanpeabody theme reference:
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/alanpeabody.zsh-theme

# set eza config directory and unset any LS_COLORS that may interfere
export EZA_CONFIG_DIR="$XDG_CONFIG_HOME/eza"
unset LS_COLORS

local user='%{$fg[green]%}%n@%{$fg[green]%}%m%{$reset_color%}'
local pwd='%{$fg[blue]%}%~%{$reset_color%}'
local return_code='%(?..%{$fg[red]%}%? ↵%{$reset_color%})'
local git_branch='$(git_prompt_status)%{$reset_color%}$(git_prompt_info)%{$reset_color%}'
local time='%{$fg[cyan]%}%T%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""

ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} ✭"
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} ✚"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%} ✹"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%} ➜"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} ✖"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%} ═"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[green]%} ↑"
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg[red]%} ↓"
ZSH_THEME_GIT_PROMPT_DIVERGED="%{$fg[yellow]%} ↕"
ZSH_THEME_GIT_PROMPT_STASHED="%{$fg[blue]%} ⚑"

PROMPT="${user}:${pwd}$ "
RPROMPT="${return_code} ${git_branch} ${time}"

##############################
###### Syntax highlighting
##############################

# set default highlighting colors
alias highlight="highlight --out-format=xterm256 --style=duotone-dark-sky"

##############################
###### Man pages
##############################

# set default colors for man pages
# some useful information this here: https://unix.stackexchange.com/questions/108699/documentation-on-less-termcap-variables
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

##############################
###### Miscellaneous commands
##############################

if [[ "$TERM" != dumb ]] && (( $+commands[grc] )) ; then

  # Supported commands
  cmds=(
    df \
    diff \
    dig \
    docker \
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

  # Set alias for available commands.
  for cmd in $cmds ; do
    if (( $+commands[$cmd] )) ; then
      alias $cmd="grc --colour=auto $(whence $cmd)"
    fi
  done

  # Clean up variables
  unset cmds cmd
fi