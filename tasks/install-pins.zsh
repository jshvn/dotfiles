#!/bin/zsh

# =============================================================================
# tasks/install-pins.zsh -- warn about each pin `task install` does not move
#
# Purpose:      The last step of `task install`. Takes the evaluated
#               declaration on stdin and checks each version the install
#               leaves alone against upstream: flake.lock's inputs (behind
#               their branch and locked over seven days ago), the NixOS
#               release line (once every input has the next branch), the
#               Taskfile's nixos/nix image (against the declared Nix), the
#               GitHub Actions `uses:` versions, macOS updates, and a jshvn/ai
#               ref that is a tag. A stale pin is a warning with its bump on
#               the line under it; a failed lookup is a warning too; nothing
#               stale prints one check.
# Depends on:   DOTFILEDIR env var; jq; git (ls-remote over HTTPS); curl
#               (api.github.com, anonymous); softwareupdate (macOS);
#               tasks/messages.zsh.
# Side effects: none beyond the network reads.
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"
: "${DOTFILEDIR:?}"
zmodload zsh/datetime

declared=$(cat)
lock="$DOTFILEDIR/flake.lock"
typeset -i stale=0 unchecked=0
export GIT_TERMINAL_PROMPT=0

pin() { warn "pins: $1"; print -r -- "       bump: $2" >&2; stale+=1; }
unknown() { warn "pins: could not check $1 (offline?)"; unchecked+=1; }

info "pins: checking what update does not move"

# --- flake.lock: one ls-remote per input repo, kept for the release line below --
# ponytail: an input without a branch ref (following its default branch) is skipped; --heads
# omits HEAD, and listing every ref would pull nixpkgs' pull-request refs too.
typeset -A HEADS REPO REF
head_rev() {
  local hit=${(M)${(f)HEADS[$1]}:#*$'\t'refs/heads/$2}
  print -r -- "${hit%%$'\t'*}"
}
behind=() failed=()
for row in ${(f)"$(jq -r '.nodes | to_entries[] | select(.value.locked.type == "github" and .value.original.ref)
  | [.key, "\(.value.locked.owner)/\(.value.locked.repo)", .value.original.ref, .value.locked.rev,
     .value.locked.lastModified] | @tsv' "$lock")"}; do
  IFS=$'\t' read -r name repo ref rev modified <<< "$row"
  REPO[$name]=$repo REF[$name]=$ref
  HEADS[$repo]=$(git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 \
    ls-remote --heads "https://github.com/$repo" 2>/dev/null || true)
  up=$(head_rev "$repo" "$ref")
  if [[ -z "${HEADS[$repo]}" ]]; then
    failed+=("$name")
  elif [[ -n "$up" && "$up" != "$rev" ]] && (( EPOCHSECONDS - modified > 7 * 86400 )); then
    behind+=("$name ($ref, locked $(strftime %F "$modified"))")
  fi
done
if (( $#failed )); then unknown "flake.lock (${(j:, :)failed})"; fi
if (( $#behind )); then
  pin "flake.lock is behind: ${(j:, :)behind}" \
    "nix flake update && git add -A && task check, then commit and push"
fi

# --- the release line: warn only once every input has the next branch ----------
cur=${${REF[nixpkgs]:-}#nixos-}
if [[ "$cur" == [0-9][0-9].[0-9][0-9] ]]; then
  lines=(${(M)${(f)HEADS[${REPO[nixpkgs]}]}:#*refs/heads/nixos-[0-9][0-9].[0-9][0-9]})
  lines=(${(On)lines##*nixos-})
  next=${lines[1]:-}
  if [[ -n "$next" && "$next" > "$cur" ]]; then
    ready=1
    for name in ${(k)REF}; do
      [[ -n "$(head_rev "${REPO[$name]}" "${REF[$name]//$cur/$next}")" ]] || ready=0
    done
    if (( ready )); then
      pin "NixOS $next is out and every input has its branch; flake.nix follows $cur" \
        "in flake.nix change each input's $cur to $next (read the release notes first), then nix flake update && git add -A && task check; home.stateVersion stays"
    fi
  fi
fi

# --- the nixos/nix image follows the declared Nix -------------------------------
tag="" nixv=${${$(jq -r '.nixPackage // ""' <<< "$declared"):t}#*-nix-}
[[ "$(<"$DOTFILEDIR/Taskfile.yml")" =~ 'nixos/nix:([^@[:space:]]+)' ]] && tag=$match[1]
if [[ -n "$tag" && -n "$nixv" && "$tag" != "$nixv" ]]; then
  pin "Taskfile.yml IMAGE is nixos/nix:$tag; the declared Nix is $nixv" \
    "curl -fsS https://hub.docker.com/v2/repositories/nixos/nix/tags/$nixv | jq -r .digest, set IMAGE to nixos/nix:$nixv@<that digest>, and the Nix row in docs/DECISIONS.md"
fi

# --- GitHub Actions: each uses: against its latest release ----------------------
workflows=("$DOTFILEDIR"/.github/workflows/*.y(a|)ml(N))
uses=()
for line in ${(M)${(f)"$( (( $#workflows )) && cat $workflows)"}:#*uses:*@*}; do
  spec=${${=${line#*uses:}}[1]}
  [[ "$spec" == ./* || "$spec" == docker://* ]] || uses+=("$spec")
done
for spec in ${(u)uses}; do
  action=${spec%@*} version=${spec##*@}
  repo=${(j:/:)${(s:/:)action}[1,2]}
  latest=$(curl -fsS --max-time 5 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null |
    jq -r '.tag_name // empty' 2>/dev/null || true)
  if [[ -z "$latest" ]]; then
    unknown "$spec"
  elif [[ "$latest" != "$version" ]]; then
    pin "$spec in .github/workflows/; the latest release is $latest" "change each uses: $spec to @$latest"
  fi
done

# --- macOS: the switch turns automatic installs off -----------------------------
if (( $+commands[softwareupdate] )); then
  found=$(softwareupdate --list 2>&1 || true)
  labels=(${${(M)${(f)found}:#\* Label: *}#\* Label: })
  if (( $#labels )); then
    pin "macOS updates available: ${(j:, :)labels}" \
      "System Settings > General > Software Update, or sudo softwareupdate --install --all --restart"
  elif [[ "$found" != *"No new software available"* ]]; then
    unknown "macOS updates"
  fi
fi

# --- jshvn/ai at a tag (a branch fast-forwards); the switch fetched its tags ----
ref=$(jq -r '.dotfiles.apps["claude-code"] | select(.enable) | .ref // empty' <<< "$declared")
dir=$(jq -r '.dotfiles.apps["claude-code"].dir // empty' <<< "$declared")
if [[ -n "$ref" && -d "$dir/.git" ]] && git -C "$dir" rev-parse -q --verify "refs/tags/$ref" >/dev/null; then
  newest=${${(f)"$(git -C "$dir" tag --sort=-v:refname)"}[1]}
  profile=$(jq -r .dotfiles.profile <<< "$declared")
  if [[ "$newest" != "$ref" ]]; then
    pin "profiles/$profile/default.nix pins jshvn/ai at $ref; its newest tag is $newest" \
      "set apps.claude-code.ref = \"$newest\" in profiles/$profile/default.nix"
  fi
fi

if (( stale == 0 && unchecked == 0 )); then check "pins: all current"; fi
