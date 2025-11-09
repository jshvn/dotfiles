#!/bin/zsh

# profile zsh startup time
function timezsh() {    # timezsh() will time how long it takes to start an interactive zsh shell. ex: $ timezsh
  shell=${1-$SHELL}
  for i in $(seq 1 4); do /usr/bin/time $shell -i -c exit; done
}