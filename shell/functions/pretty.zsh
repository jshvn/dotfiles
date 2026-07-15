#!/bin/zsh

# =============================================================================
# shell/functions/pretty.zsh -- pretty-print and syntax-highlight JSON/YAML/TOML
#
# Purpose:      Reformat a JSON, YAML, or TOML file with the canonical tool
#               for its type, then pipe through highlight for color. Format
#               is chosen from the file extension (.json / .yaml|.yml /
#               .toml). Supersedes the JSON-only prettyjson.
# Depends on:   jq (JSON), yq (YAML), taplo (TOML), highlight.
# Side effects: stdout only.
# =============================================================================

function pretty() {    # pretty() pretty-prints + highlights a JSON/YAML/TOML file. ex: $ pretty manifests/features.toml
	if [[ -z "${1}" ]]; then
		echo "ERROR: No file specified";
		return 1;
	fi
    if [[ ! -f "${1}" ]]; then
        echo "ERROR: file not found: ${1}" >&2
        return 1
    fi

    local ext="${${1##*.}:l}"
    case "$ext" in
        json)
            jq '.' "${1}" | highlight --syntax=json
            ;;
        yaml|yml)
            yq -P '.' "${1}" | highlight --syntax=yaml
            ;;
        toml)
            taplo fmt - < "${1}" | highlight --syntax=toml
            ;;
        *)
            echo "ERROR: unsupported type '.${ext}' (expected json, yaml, yml, or toml)" >&2
            return 2
            ;;
    esac
}
