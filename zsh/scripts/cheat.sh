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
 

cheathelp="""
Available cheat functions:
    $ cheat reload      :   reloads zsh configuration
    $ cheat conda [pdf] :   lists useful conda functions and operations. append 'pdf' to open pdf copy    
    $ cheat zsh         :   lists useful zsh tips and tricks
    $ cheat aliases     :   lists all of the custom aliases defined in dotfiles
    $ cheat functions   :   lists all of the custom fucntions defined in dotfiles
    $ cheat help        :   views this help document
"""


function cheat() {
    case $1 in
        conda)              
            case $2 in 
                pdf)        open "$cheatsdir/pdf/conda.pdf"                                         ;;
                *)          glow --style "$cheatsdir/glow_style.json" "$cheatsdir/md/conda.md"      ;;
            esac
        ;;
        zsh|bash|sh)        glow --style "$cheatsdir/glow_style.json" "$cheatsdir/md/zsh.md"        ;;
        alias|aliases)      highlight "$rootdir/zsh/aliases.zsh"                                    ;;
        func|functions)     highlight "$rootdir/zsh/functions.zsh"                                  ;;
        help|*)             echo "$cheathelp"                                                       ;;
    esac
}