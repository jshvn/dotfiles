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
        alias|aliases)      highlight "$DOTFILEDIR/zsh/aliases.zsh"                                    ;;
        func|functions)     highlight "$DOTFILEDIR/zsh/functions.zsh"                                  ;;
        help|*)             glow --style "$CHEATSDIR/glow_style.json" -w 120 "$CHEATSDIR/cheat.md"                                                      ;;
    esac
}