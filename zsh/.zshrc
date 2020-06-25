# miniconda3

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

# Path to cloned dotfiles repo
export DOTFILES=$HOME/git/personal/dotfiles