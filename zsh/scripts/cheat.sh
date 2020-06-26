# set cheatsdir to the directory where cheat markdown files are located
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
GITDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
parentdir="$(dirname "$GITDIR")"
cheatsdir="$(dirname "$parentdir")"/cheat/
 

function cheat() {
    case $1 in
        conda)   glow --style "$cheatsdir/glow_style.json" "$cheatsdir/conda.md"    ;;
        help)    echo "blah"     ;;
        *)       echo "'$1' wasn't found in list of cheat sheets" ;;
    esac

}