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
    local commonlist=$(grep '^alias' "$DOTFILEDIR/zsh/common/aliases.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    
    # grab all of the platform specific aliases
    local platformlist="\n"
    if [[ $(uname) == "Darwin" ]]; then
        platformlist+=$(grep '^alias' "$DOTFILEDIR/zsh/macos/aliases.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    else
        platformlist+=$(grep '^alias' "$DOTFILEDIR/zsh/linux/aliases.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    fi

    # combine and print
    local combined="$commonlist"+"$platformlist"
    echo "$combined" | sort -u -d -s
}

function functionlist() {
    # grab all of the common functions to both platforms
    local commonlist=$(grep '^function' "$DOTFILEDIR/zsh/common/functions.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    
    # grab all of the platform specific functions
    local platformlist="\n"
    if [[ $(uname) == "Darwin" ]]; then
        platformlist+=$(grep '^function' "$DOTFILEDIR/zsh/macos/functions.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    else
        platformlist+=$(grep '^function' "$DOTFILEDIR/zsh/linux/functions.zsh" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    fi

    # grab all of the functions defined in the scripts directory
    local scriptfunctionlist=""
    for script in $DOTFILEDIR/zsh/common/scripts/*; do 
        scriptfunctionlist+="\n"+$(grep '^function' "$script" | highlight --syntax=bash --out-format=xterm256 --style=fine_blue)
    ; done

    # combine and print
    local combined="$commonlist"+"$platformlist"+"$scriptfunctionlist"
    echo "$combined" | sort -u -d -s | tr -d '\\+'
}