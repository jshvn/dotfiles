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
    local COMMONLIST=$(grep alias "$DOTFILEDIR/zsh/common/aliases.zsh" | highlight --syntax=bash --out-format=xterm256)
    if [[ $(uname) == "Darwin" ]]; then
        local PLATFORMLIST=$(grep alias "$DOTFILEDIR/zsh/macos/aliases.zsh" | highlight --syntax=bash --out-format=xterm256)
    else
        local PLATFORMLIST=$(grep alias "$DOTFILEDIR/zsh/linux/aliases.zsh" | highlight --syntax=bash --out-format=xterm256)
    fi
    local COMBINED="$COMMONLIST"+"$PLATFORMLIST"
    echo "$COMBINED" | sort -u -d -s
}

function functionlist() {
    local COMMONLIST=$(grep 'function' "$DOTFILEDIR/zsh/common/functions.zsh" | highlight --syntax=bash --out-format=xterm256)
    if [[ $(uname) == "Darwin" ]]; then
        local PLATFORMLIST=$(grep 'function' "$DOTFILEDIR/zsh/macos/functions.zsh" | highlight --syntax=bash --out-format=xterm256)
    else
        local PLATFORMLIST=$(grep 'function' "$DOTFILEDIR/zsh/linux/functions.zsh" | highlight --syntax=bash --out-format=xterm256)
    fi
    local COMBINED="$COMMONLIST"+"$PLATFORMLIST"
    echo "$COMBINED" | sort -u -d -s
}