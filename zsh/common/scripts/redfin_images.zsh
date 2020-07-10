#!/bin/zsh

function redfinimages() { # redfinimages() will fetch all images from a redfin listing. ex $ redfinimages https://www.redfin.com/WA/Kirkland/14702-120th-Ct-NE-98034/home/455905
    if [ -z "${1}" ]; then
		echo "ERROR: No listing URL specified";
		return 1;
	fi;

    wget --user-agent="Mozilla" -O - $1 | echo -e $(egrep -o "https:\\\\u002F\\\\u002Fssl.cdn-redfin.com\\\\u002Fphoto\\\\u002F\d*247\\\\u002Fbigphoto\\\\u002F426\\\\u002FE[0-9_]*.jpg") | xargs wget --user-agent="Mozilla" | rm *.jpg.*
}
