#!/bin/zsh

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# set XDG_CONFIG_HOME
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# tool defaults
export EDITOR="nano"
export VEDITOR="code"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="alanpeabody"

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
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    colorize
    zsh-syntax-highlighting
    zsh-autosuggestions
)

# Perform compinit only once a day for speed
# https://gist.github.com/ctechols/ca1035271ad134841284#gistcomment-2308206
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
  compinit
done
compinit -C

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

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
# Add visual studio code to the path if it isn't already there
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ] && [[ ":$PATH:" != *":/Applications/Visual Studio Code.app/Contents/Resources/app/bin:"* ]]; then
    PATH="${PATH:+"$PATH:"}/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

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

# load jgrid environment scripts
for file in "$DOTFILEDIR/zsh/jgrid/"*
do
    if [[ -f $file ]]; then
        source $file
    fi
done

# load ZSH function and helper scripts
for file in "$DOTFILEDIR/zsh/functions/"*
do
    if [[ -f $file ]]; then
        source $file
    fi
done