#!/bin/zsh

# pretty print json
function prettyjson() {    # prettyjson() will print human readable json that has been colorized. ex: $ prettyjson file.json
	if [ -z "${1}" ]; then
		echo "ERROR: No file specified";
		return 1;
	fi;

  result=$(cat $1 | python3 -m json.tool)
  echo $result | highlight --syntax=json
}