#!/bin/zsh

# =============================================================================
# shell/functions/motd.zsh -- message-of-the-day banner in the jshvn brand
#
# Purpose:      Display a centered banner: the jshvn mark and name, fastfetch
#               system info, the dotfiles repo (last commit, uncommitted
#               count, switch drift) and git news (open pull requests,
#               failing workflows, local repos left dirty or unpushed), in the
#               brand's greys for a dark surface. Anything slow or networked
#               is read from a cache that background jobs refresh, so the
#               banner never waits. Helpers live at file scope and rely on zsh
#               dynamic scoping to read width / reset / muted / body / cache
#               from motd()'s locals. Terminals with an image protocol get the
#               mark as a PNG; others the brand's block-character mark.
# Depends on:   tput, curl, gh, git, fastfetch (optional), sed, tr, base64,
#               zsh/stat, zsh/datetime, $DOTFILEDIR, $XDG_CACHE_HOME,
#               shell/motd/motd_sysinfo.jsonc,
#               /run/current-system/darwin-version.json,
#               https://brand.ijosh.com/mark/jshvn-mark-on-dark-512.png.
# Side effects: stdout; background jobs rewrite $XDG_CACHE_HOME/dotfiles/motd/.
# =============================================================================

zmodload zsh/datetime
zmodload -F zsh/stat b:zstat

# Helpers rely on zsh dynamic scoping: motd() declares width/reset/muted as
# locals, and these helpers read them at call time.
# An optional third argument centers on that many columns instead of the text.
_motd_center() {
    local text="$1"
    local color="$2"
    local padding=$(( (width - ${3:-${#text}}) / 2 ))
    printf "%*s${color}%s${reset}\n" $padding "" "$text"
}

_motd_line() {
    printf "${1:-$muted}%*s${reset}\n" $width | tr ' ' "${2:-━}"
}

# Draws the PNG at $1 inline: the kitty graphics protocol (kitty, Ghostty) or
# the iTerm2 protocol (iTerm2, WezTerm). Returns 1 where neither applies, when
# the PNG is not cached yet, and inside tmux, which drops both unless
# passthrough is on.
_motd_image() {
    # Sized in columns, the unit the padding is in; the height follows the
    # font. Even, like the block-character mark and the name below it.
    local png="$1" cols=24
    [[ -r "$png" && -z "$TMUX" ]] || return 1
    local pad=$(( (width - cols) / 2 ))
    local b64=$(base64 < "$png" | tr -d '\n')

    if [[ "$TERM" == (xterm-kitty|xterm-ghostty) ]]; then
        # Chunks of 4096 (the protocol's limit); q=2 keeps replies out of the
        # prompt. The terminal leaves the cursor on the image's last row.
        local i=0 more
        printf '%*s' $pad ''
        while (( i < ${#b64} )); do
            more=$(( i + 4096 < ${#b64} ))
            if (( i == 0 )); then
                printf '\e_Gf=100,a=T,c=%d,q=2,m=%d;%s\e\\' $cols $more "${b64:$i:4096}"
            else
                printf '\e_Gm=%d;%s\e\\' $more "${b64:$i:4096}"
            fi
            (( i += 4096 ))
        done
        printf '\n'
    elif [[ "$TERM_PROGRAM" == (iTerm.app|WezTerm) ]]; then
        printf '%*s\e]1337;File=inline=1;width=%d;preserveAspectRatio=1:%s\a\n' $pad '' $cols "$b64"
    else
        return 1
    fi
}

# Sets REPLY to the seconds since $1 last changed; a missing file is ancient.
_motd_age() {
    local -a mtime
    if zstat -A mtime +mtime -- "$1" 2>/dev/null; then
        REPLY=$(( EPOCHSECONDS - mtime[1] ))
    else
        REPLY=$EPOCHSECONDS
    fi
}

# Kills process $1 and everything under it, children first: killing a parent
# first would orphan its children out of reach of pgrep -P. A job's own
# process group is not an option: zsh refuses job control without a terminal.
_motd_kill_tree() {
    local child
    for child in $(pgrep -P $1); do
        _motd_kill_tree $child
    done
    kill $1 2>/dev/null
}

# Rewrites cache file $1 from the output of function $3, in the background,
# when the file is older than $2 minutes. A mkdir lock keeps it to one job
# however many shells start at once; a lock older than 5 minutes belongs to a
# job that died, and is taken over. A watchdog kills the job's whole tree at
# 60 s (a hung gh with it), and the file is replaced only on success, so a
# failure keeps the last good copy.
_motd_refresh() {
    local file="$1" lock="$1.lock"
    _motd_age "$file"
    (( REPLY < $2 * 60 )) && return
    mkdir -p "${file:h}"
    if ! mkdir "$lock" 2>/dev/null; then
        _motd_age "$lock"
        (( REPLY > 300 )) || return
        rm -rf "$lock"
        mkdir "$lock" 2>/dev/null || return
    fi
    {
        "$3" > "$file.$$" &
        local job=$!
        { sleep 60 && _motd_kill_tree $job } &
        local dog=$!
        wait $job && mv -f "$file.$$" "$file"
        _motd_kill_tree $dog
        rm -rf "$file.$$" "$lock"
    } </dev/null &>/dev/null &!
}

# Prints cached line $2 under label $1. A line older than three times its
# refresh age ($3 minutes) carries its age, so stale news never reads as
# current. No cache yet, no line.
_motd_cached() {
    local file="$cache/$2" ago
    [[ -s "$file" ]] || return
    _motd_age "$file"
    if (( REPLY > 3 * $3 * 60 )); then
        if (( REPLY < 3600 )); then ago="$(( REPLY / 60 ))m"
        elif (( REPLY < 86400 )); then ago="$(( REPLY / 3600 ))h"
        else ago="$(( REPLY / 86400 ))d"
        fi
        ago=" ${muted}· ${ago} ago"
    fi
    print -r -- "   ${muted}$1${reset} › ${body}$(<$file)${ago}${reset}"
}

_motd_mark() {
    curl -fsS --max-time 10 https://brand.ijosh.com/mark/jshvn-mark-on-dark-512.png
}

# Open pull requests across jshvn's repos, Dependabot's included.
_motd_prs() {
    local out
    out=$(gh search prs --owner jshvn --state open --limit 100 \
        --json repository,number --jq '.[] | "\(.repository.name)#\(.number)"') || return
    local -a prs=( ${(f)out} )
    (( $#prs )) || { print none; return }
    print -r -- "$#prs: ${(j:, :)prs[1,3]}${prs[4]:+ +$(( $#prs - 3 ))}"
}

# Workflows whose latest finished run on the default branch failed, as
# repo/workflow; one that failed and then passed drops off. A repo with no
# runs in its last 30 says nothing. One gh call per repo, all at once: in a
# row they take half a minute. Any call failing fails the refresh.
_motd_runs() {
    local repos repo branch tmp
    repos=$(gh repo list jshvn --no-archived --source --limit 200 \
        --json name,defaultBranchRef --jq '.[] | "\(.name) \(.defaultBranchRef.name)"') || return
    tmp=$(mktemp -d) || return
    # The braces matter: zsh runs a bare `a || b &` with a in the foreground
    for repo branch in ${=repos}; do
        {
            gh run list -R "jshvn/$repo" --branch "$branch" --limit 30 \
                --json workflowName,status,conclusion,createdAt --jq '
                    [.[] | select(.status == "completed")] | group_by(.workflowName)[]
                    | max_by(.createdAt)
                    | select(.conclusion | IN("failure", "timed_out", "startup_failure"))
                    | "'"$repo"'/" + .workflowName' > "$tmp/$repo" || touch "$tmp/failed"
        } &
    done
    wait
    local -a failing=( ${(f)"$(cat "$tmp"/*(N))"} )
    [[ -e "$tmp/failed" ]] && { rm -rf "$tmp"; return 1 }
    rm -rf "$tmp"
    print -r -- "${${(j:, :)failing}:-none}"
}

# Repos under ~/Git with commits not pushed or changes not committed, dotfiles
# aside (it has its own section). Nothing is fetched, so unpushed is against
# the last fetched upstream; a branch with no upstream counts as unpushed.
# --no-optional-locks keeps this off index.lock while you commit.
_motd_repos() {
    setopt local_options null_glob
    local git dir name
    local -a st unpushed dirty
    for git in ~/Git/*/*/.git; do
        dir=${git:h}
        [[ ${dir:A} == ${DOTFILEDIR:A} ]] && continue
        name=${dir:t}
        st=( "${(@f)$(git --no-optional-locks -C "$dir" status --porcelain -b 2>/dev/null)}" )
        (( $#st > 1 )) && dirty+=( $name )
        if [[ $st[1] =~ 'ahead ([0-9]+)' ]]; then
            unpushed+=( "$name ($match[1])" )
        elif [[ $st[1] == '## '* && $st[1] != *...* && $st[1] != '## HEAD '* ]]; then
            unpushed+=( "$name (no upstream)" )
        fi
    done
    local -a parts
    (( $#unpushed )) && parts+=( "unpushed: ${(j:, :)unpushed}" )
    (( $#dirty )) && parts+=( "dirty: ${(j:, :)dirty}" )
    print -r -- "${${(j: · :)parts}:-clean}"
}

# The switch against the checkout: commits since the activated revision that
# touch the Nix side. Files linked from the checkout are live without one.
# ponytail: counts *.nix and flake.lock only, so a file an activation script
# copies into the store (${./file}) is missed. Upgrade: compare the evaluated
# toplevel with /run/current-system in a background job.
_motd_switch() {
    local json=/run/current-system/darwin-version.json n
    [[ -r $json && "$(<$json)" =~ '"configurationRevision": *"([0-9a-f]+)(-dirty)?"' ]] || return
    [[ -n $match[2] ]] && { print "built from uncommitted changes"; return }
    n=$(git -C "$DOTFILEDIR" rev-list --count "$match[1]..HEAD" -- '*.nix' flake.lock 2>/dev/null) ||
        { print "unknown revision ${match[1]:0:7}"; return }
    (( n == 0 )) && print current || print "$n commit${${n:#1}:+s} behind · task install"
}

_motd_dotfiles() {
    [[ -d "${DOTFILEDIR}/.git" ]] || return
    local last_commit=$(git -C "$DOTFILEDIR" log -1 --format="%ar" 2>/dev/null || echo "unknown")
    local changes=$(git -C "$DOTFILEDIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local switch=$(_motd_switch)

    echo "${strong}DOTFILES${reset}"
    echo "   ${muted}Last commit${reset} › ${body}${last_commit}${reset}"
    echo "   ${muted}Changes${reset} › ${body}${changes}${reset}"
    [[ -n $switch ]] && echo "   ${muted}Switch${reset} › ${body}${switch}${reset}"
    echo
}

_motd_git() {
    local lines=$(
        _motd_cached "Pull requests" prs 5
        _motd_cached "Failing" runs 15
        _motd_cached "Local" repos 1
    )
    [[ -n $lines ]] || return
    echo "${strong}GIT${reset}"
    print -r -- "$lines"
    echo
}

function motd() {    # motd() prints the message-of-the-day banner. ex: $ motd
    # The brand's dark-surface tokens: --text, --text-body, --text-muted.
    # ponytail: 24-bit escapes only; a terminal without truecolor (Terminal.app
    # before macOS 26) shows wrong colors. Upgrade: a tput setaf 256 fallback.
    local strong=$'\e[38;2;244;247;251m'
    local body=$'\e[38;2;198;208;218m'
    local muted=$'\e[38;2;154;167;180m'
    local reset=$(tput sgr0)
    local width=$(tput cols)
    local cache="${XDG_CACHE_HOME}/dotfiles/motd"

    # Refresh ages in minutes: the mark daily, GitHub every few, local repos
    # every shell that starts a minute after the last
    _motd_refresh "$cache/mark.png" 1440 _motd_mark
    _motd_refresh "$cache/prs" 5 _motd_prs
    _motd_refresh "$cache/runs" 15 _motd_runs
    _motd_refresh "$cache/repos" 1 _motd_repos

    echo
    _motd_line
    echo

    # The mark: the PNG where the terminal draws one, else the brand's solid
    # form, two block characters per grid cell so the cells come out square
    if ! _motd_image "$cache/mark.png"; then
        _motd_center "  ████" "$strong"
        _motd_center "██  ██" "$strong"
        _motd_center "██████" "$strong"
    fi
    echo
    _motd_center "JOSH VAUGHEN" "$strong"
    echo

    # System info via fastfetch
    echo "${strong}SYSTEM${reset}"
    local ff_config="${DOTFILEDIR}/shell/motd/motd_sysinfo.jsonc"
    if [[ -f "$ff_config" ]]; then
        fastfetch --config "$ff_config" 2>/dev/null | sed "s/^/   /"
    else
        fastfetch 2>/dev/null | sed "s/^/   /" || echo "   ${muted}fastfetch not configured${reset}"
    fi
    echo

    _motd_dotfiles
    _motd_git

    _motd_line
    echo
}
