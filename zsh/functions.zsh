#!/bin/zsh

# this file is meant to encapsulate funcs that are general and cover things like
# files, system operations, dotfile changes, etc.

# any scripts that interact with APIs or non-system software should be placed
# in their own script in the scripts subdirectory

# this func allows you to easily list all of the available funcs
function functionlist() {
    # grab all of the common funcs to both platforms
    local list=$(grep 'function' "$DOTFILEDIR/zsh/functions.zsh" | awk '{$1=$1};1' | highlight --syntax=bash)

    echo "$list" | sort -u -d -s | tr -d '\\+'
}

# update the dotfiles completely
function update() {    # update() will update the current dotfiles installation and dependencies. ex: $ update
	# save the current directory
	currentdir=$(pwd)

	# navigate to dotfile install directory
	dotfiles

	# pull new version from origin
	git pull
	
	# execute the install script
	# note: we manually specify bash here, since the install script is written in bash 
	# and we're calling it from zsh. bad things happen if you use source instead
	bash $DOTFILEDIR/install/install.sh

    # update tldr definitions
    tldr --update

	# return user to previous directory
	cd $currentdir
}

# Extract a compressed archive without worrying about which tool to use
function extract() { # extract() will unzip/unrar/untar any type of compressed file. ex $ extract file.tar.gz
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1    ;;
      *.tar.gz)    tar xzf $1    ;;
      *.bz2)       bunzip2 $1    ;;
      *.rar)       unrar x $1    ;;
      *.gz)        gunzip $1     ;;
      *.tar)       tar xf $1     ;;
      *.tbz2)      tar xjf $1    ;;
      *.tgz)       tar xzf $1    ;;
      *.zip)       unzip $1      ;;
      *.Z)         uncompress $1 ;;
      *.7z)        7z x $1       ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Determine size of a file or total size of a directory
function fs() {    # fs() will print a human readable size of given file or directory. ex: $ fs ~
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi
	if [[ -n "$@" ]]; then
		du $arg -- "$@";
	else
        if [[ $(uname) == "Darwin" ]]; then
            du $arg .[^.]* ./*;
        else
            find . -type f | du -ah -d1
        fi;
	fi;
}

# Prints permissions of file
function permissions() {    # permissions() will print human readable permissions for a given file or directory. ex: $ permissions ~
	if [ -z "${1}" ]; then
		echo "ERROR: No file or directory specified";
		return 1;
	fi;

    if [[ $(uname) == "Darwin" ]]; then
        stat -f "%Sp %OLp %N" $1
    else
        stat -c '%A %a %n' $1
    fi;
}


# pretty print json
function prettyjson() {    # prettyjson() will print human readable json that has been colorized. ex: $ prettyjson file.json
	if [ -z "${1}" ]; then
		echo "ERROR: No file specified";
		return 1;
	fi;

  result=$(cat $1 | python -m json.tool)
  echo $result | highlight --syntax=json
}

####################################################################################
#################################### macOS #########################################
####################################################################################

# Execute setup depending on the system
if [[ `uname` == "Darwin" ]]; then

    # open vnc connection
    function vnc() {    # vnc() will open a VNC connection to a given host. ex: $ vnc copper.jgrid.net
        if [ -z "${1}" ]; then
            echo "ERROR: No domain specified.";
            return 1;
        fi;
        open vnc://$1
    }

    # copy primary public key to clipboard
    function pubkey() {    # pubkey() will copy a public key to the clipboard. ex: $ pubkey id_rsa_adobe.pub
        if [ -z "${1}" ]; then
            echo "ERROR: No key specified. The possible keys are:";
            local keylist=$(ls ~/.ssh/*.pub);
            echo $keylist;
            return 1;
        fi;
        more ~/.ssh/$1 | pbcopy | echo '=> Public key copied to clipboard.'
    }

    # list all ssh endpoints from /ssh/.ssh/config
    function sshlist() {    # sshlist() will list all available ssh endpoints. ex: $ sshlist
        local CONFIG_PATH=("$DOTFILEDIR/ssh/configs"/*)
        for f in $CONFIG_PATH
        do
            cat "$f" | 
                grep -e "Host " -e "######## " -e "#### $" |
                grep -v "Host \*" |
                grep "Host \|####"
        done
    }

    # set the computer's hostname to specified name
    function sethostname() {    # sethostname() will set the machine's hostname to the given string. ex: $ sethostname JWORK
        if [ -z "${1}" ]; then
            echo "ERROR: No hostname specified.";
            return 1;
        fi;
        sudo scutil --set ComputerName $1
        sudo scutil --set HostName $1
        sudo scutil --set LocalHostName $1
        sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $1
    }

    # afk func
    function afk() {	# afk() will suspend the current session and lock the screen. ex: $ afk
        autoload is-at-least
        if is-at-least 11.0 $(sw_vers -productVersion); then
            # big sur or greater
            osascript -e 'tell app "System Events" to key code 12 using {control down, command down}'
        else
            # catalina or lower
            /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
        fi
    }


fi
####################################################################################
#################################### Linux #########################################
####################################################################################




