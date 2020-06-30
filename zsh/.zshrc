#!/bin/zsh

####################################################################################
#################################### Common ########################################
####################################################################################


# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# tool defaults
export EDITOR="nano"
export VEDITOR="code"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="alanpeabody"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

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

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

#  Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"

# load cheat scripts
source $DOTFILEDIR/zsh/cheat/cheat.zsh

# load common ZSH aliases
source $DOTFILEDIR/zsh/common/aliases.zsh

# load common ZSH functions
source $DOTFILEDIR/zsh/common/functions.zsh

# load common ZSH custom themes
source $DOTFILEDIR/zsh/theme.zsh

# load common helper scripts
for file in "$DOTFILEDIR/zsh/common/scripts/"*
do
    if [[ -f $file ]]; then
        source $file
    fi
done


if [[ $(uname) == "Darwin" ]]; then
    ####################################################################################
    #################################### macOS #########################################
    ####################################################################################
    export VISUAL="code"
    export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox-bin"

    # load ZSH custom aliases
    source $DOTFILEDIR/zsh/macos/aliases.zsh

    # load ZSH custom functions
    source $DOTFILEDIR/zsh/macos/functions.zsh

    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/Users/josh/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/Users/josh/miniconda3/etc/profile.d/conda.sh" ]; then
            . "/Users/josh/miniconda3/etc/profile.d/conda.sh"
        else
            export PATH="/Users/josh/miniconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<

    # Add visual studio code to the path if it isn't already there
    if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ] && [[ ":$PATH:" != *":/Applications/Visual Studio Code.app/Contents/Resources/app/bin:"* ]]; then
        PATH="${PATH:+"$PATH:"}/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    fi


else
    ####################################################################################
    #################################### Linux #########################################
    ####################################################################################

    # eventually figure out what to export for visual and browser
    #export VISUAL="code"
    #export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox-bin"

    # make sure our brew applications can be found
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

    # load ZSH custom aliases
    source $DOTFILEDIR/zsh/linux/aliases.zsh

    # load ZSH custom functions
    source $DOTFILEDIR/zsh/linux/functions.zsh
fi