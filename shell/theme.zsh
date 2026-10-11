#!/bin/zsh

# =============================================================================
# shell/theme.zsh -- prompt + man-page + grc colour setup
#
# Purpose:      Start the Starship prompt (apps/starship/starship.toml); set
#               man + grc colours.
# Depends on:   starship, eza, grc on PATH; ~/.config/starship.toml (linked
#               by the switch); XDG_CONFIG_HOME, XDG_CACHE_HOME (.zshenv).
# Side effects: unsets LS_COLORS; exports STARSHIP_CONFIG, STARSHIP_CACHE;
#               in Terminal.app writes $XDG_CACHE_HOME/starship/plain.toml;
#               sets PROMPT, RPROMPT and Starship's precmd/preexec hooks;
#               redefines man() with LESS_TERMCAP_* colour env; aliases
#               supported commands through `grc --colour=auto`.
# =============================================================================

unset LS_COLORS

# STARSHIP_CONFIG is set on every start, so a value inherited from another terminal never sticks.
# Terminal.app draws no Nerd Font glyphs: it gets a copy of starship.toml in which each rounded
# pill end (U+E0B6 or U+E0B4, escaped, coloured with fg:) is a plain cell coloured with bg:. The
# copy is rebuilt whenever starship.toml is newer.
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
export STARSHIP_CACHE="$XDG_CACHE_HOME/starship"
if [[ "$TERM_PROGRAM" == Apple_Terminal && -f "$STARSHIP_CONFIG" ]]; then
  () {
    setopt localoptions extendedglob
    local plain="$STARSHIP_CACHE/plain.toml" toml
    if [[ ! "$plain" -nt "$STARSHIP_CONFIG" ]]; then
      mkdir -p "$STARSHIP_CACHE"
      toml="$(<"$STARSHIP_CONFIG")"
      print -r -- "${toml//(#b)\[\\ue0b[46]\]\(fg:([a-z-]##)\)/[ ](bg:${match[1]})}" >| "$plain"
    fi
    STARSHIP_CONFIG="$plain"
  }
fi

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  echo "$(tput setaf 3)Warning: starship not found. Run 'task install' to complete setup.$(tput sgr0)" >&2
fi

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
