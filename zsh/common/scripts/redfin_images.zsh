#!/bin/zsh

function redfinimages() {
    if [ -z "${1}" ]; then
		echo "ERROR: No listing URL specified";
		return 1;
	fi;

    wget --user-agent="Mozilla" -O - $1 | echo -e $(egrep -o "https:\\\\u002F\\\\u002Fssl.cdn-redfin.com\\\\u002Fphoto\\\\u002F\d*247\\\\u002Fbigphoto\\\\u002F426\\\\u002FE[0-9_]*.jpg") | xargs wget --user-agent="Mozilla" | rm *.jpg.*
}
