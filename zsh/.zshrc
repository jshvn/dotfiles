#!/bin/zsh

# set XDG_CONFIG_HOME
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# tool defaults
export EDITOR="nano"
export VEDITOR="code"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# export HIST_STAMPS="%Y-%m-%d %I:%M:%S"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Perform compinit only once a day for speed
# https://gist.github.com/ctechols/ca1035271ad134841284#gistcomment-2308206
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

# set antigen config location
export ADOTDIR=$XDG_CONFIG_HOME/antigen

# load antigen for plugin management
source $(brew --prefix)/share/antigen/antigen.zsh

# load the oh-my-zsh's library.
antigen use ohmyzsh/ohmyzsh

# load plugins for oh-my-zsh
antigen bundle ohmyzsh/ohmyzsh git
antigen bundle ohmyzsh/ohmyzsh colorize
antigen bundle ohmyzsh/ohmyzsh kubectl
antigen bundle ohmyzsh/ohmyzsh plugins/extract
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions

# apply antigen plugin settings
antigen apply

#  Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"
export DOTFILEDIR

# set visual code editor to VS Code
export VISUAL="code"

# set browser to Firefox
export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"

# Set 1Password as SSH agent on macOS
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# Initialize conda for current shell
eval "$(conda "shell.$(basename "${SHELL}")" hook)"

# the below sources need to happen after the above shell initializations
# otherwise some functions/scripts like 'which' will not be found in the 
# correct spots, and that causes errors in aliases and functions

# load ZSH aliases
for file in "$DOTFILEDIR/zsh/aliases/"*
do
    if [[ -f $file ]]; then
        source $file
    fi
done

# load common ZSH custom themes
source $DOTFILEDIR/zsh/theme.zsh

# load ZSH function and helper scripts
for file in "$DOTFILEDIR/zsh/functions/"*
do
    if [[ -f $file ]]; then
        source $file
    fi
done