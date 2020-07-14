# Geo IP lookup helper, uses # https://freegeoip.app/ as source
function geoip() {    # geoip() will print geolocation information for a given IP or host. ex: $ geoip 1.1.1.1
		if [ -z "${1}" ]; then
		echo "ERROR: No IP or host specified";
		return 1;
	fi;

	jsonobject=$(curl -s --request GET --url https://freegeoip.app/json/$1 --header 'accept: application/json' --header 'content-type: application/json' | python -m json.tool)
	echo $jsonobject | highlight-blue --syntax=json
}