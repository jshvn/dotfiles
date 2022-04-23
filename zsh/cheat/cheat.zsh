#!/bin/zsh

# set CHEATSDIR to the directory where cheat files are located
CHEATSDIR="$DOTFILEDIR"/zsh/cheat/

function cheat() {
    case $1 in
        conda)              
            case $2 in 
                pdf)        open "$CHEATSDIR/pdf/conda.pdf"                                         ;;
                *)          glow --style "$CHEATSDIR/glow_style.json" -w 120 "$CHEATSDIR/md/conda.md"      ;;
            esac
        ;;
        git)              
            case $2 in 
                pdf)        open "$CHEATSDIR/pdf/git.pdf"                                         ;;
                *)          glow --style "$CHEATSDIR/glow_style.json" -w 120 "$CHEATSDIR/md/git.md"      ;;
            esac
        ;;
        zsh|bash|sh)        glow --style "$CHEATSDIR/glow_style.json" -w 120 "$CHEATSDIR/md/zsh.md"        ;;
        alias|aliases)      aliaslist                                    ;;
        func|functions)     functionlist                                  ;;
        help|*)             glow --style "$CHEATSDIR/glow_style.json" -w 120 "$CHEATSDIR/cheat.md"                                                      ;;
    esac
}


function aliaslist() {
    # grab all of the common aliases to both platforms
    local list=$(grep 'alias' "$DOTFILEDIR/zsh/aliases.zsh" | awk '{$1=$1};1' | highlight --syntax=bash)

    echo "$list" | sort -u -d -s
}

function functionlist() {
    # grab all of the common functions to both platforms
    local list=$(grep 'function' "$DOTFILEDIR/zsh/functions.zsh" | awk '{$1=$1};1' | highlight --syntax=bash)

    echo "$list" | sort -u -d -s | tr -d '\\+'
}