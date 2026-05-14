#!/bin/zsh

# Display configured SSH host information
function sshlist() {    #  sshlist() will list all configured SSH hosts. ex: $ sshlist
    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""

    # Main SSH config (always show)
    echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
    if [[ -f "$DOTFILEDIR/ssh/configs/config" ]]; then
        grep -E "^Host " "$DOTFILEDIR/ssh/configs/config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi

    # Per-identity SSH config display deferred to Phase 4 (IDNT-03).

    echo ""
    echo "$(tput setaf 8)Config file: $DOTFILEDIR/ssh/configs/config$(tput sgr0)"
}
