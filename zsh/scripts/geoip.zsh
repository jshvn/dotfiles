# Geo IP lookup helper, uses # https://ip.guide/ as source
function geoip() {    # geoip() will print geolocation information for a given IP or host. ex: $ geoip 1.1.1.1
    if [ -z "${1}" ]; then
		echo "ERROR: No IP or host specified";
		return 1;
	fi;

    local jsonobject=$(curl -sL --request GET --url ip.guide/$1 --header 'accept: application/json' --header 'content-type: application/json' | python -m json.tool)
    echo $jsonobject | highlight --syntax=json
}