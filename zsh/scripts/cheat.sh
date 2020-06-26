# set cheatsdir to the directory where cheat markdown files are located
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
GITDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
parentdir="$(dirname "$GITDIR")"
rootdir="$(dirname "$parentdir")"
cheatsdir="$rootdir"/cheat/

function cheat() {
    case $1 in
        conda)              
            case $2 in 
                pdf)        open "$cheatsdir/pdf/conda.pdf"                                         ;;
                *)          glow --style "$cheatsdir/glow_style.json" -w 120 "$cheatsdir/md/conda.md"      ;;
            esac
        ;;
        git)              
            case $2 in 
                pdf)        open "$cheatsdir/pdf/git.pdf"                                         ;;
                *)          glow --style "$cheatsdir/glow_style.json" -w 120 "$cheatsdir/md/git.md"      ;;
            esac
        ;;
        zsh|bash|sh)        glow --style "$cheatsdir/glow_style.json" -w 120 "$cheatsdir/md/zsh.md"        ;;
        alias|aliases)      highlight "$rootdir/zsh/aliases.zsh"                                    ;;
        func|functions)     highlight "$rootdir/zsh/functions.zsh"                                  ;;
        help|*)             glow --style "$cheatsdir/glow_style.json" -w 120 "$cheatsdir/cheat.md"                                                      ;;
    esac
}