#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/install-pins.zsh -- smoke tests for tasks/install-pins.zsh
#
# Purpose:      Against a throwaway checkout (flake.lock, Taskfile.yml, a
#               workflow), a throwaway jshvn/ai repo with two tags, and fake
#               git ls-remote, curl and softwareupdate answering from fixture
#               files: every pin current (including an input behind by less
#               than seven days and a release line only nixpkgs has cut) prints
#               "all current" and no warning; every pin stale prints each
#               warning with its bump line; no network prints "could not
#               check". Every run exits 0.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml);
#               tasks/install-pins.zsh; tasks/messages.zsh; git; jq.
# Side effects: creates a sandbox under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"
source "${DOTFILEDIR}/tasks/messages.zsh"
zmodload zsh/datetime

typeset -i failures=0
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/install-pins-test.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT INT TERM
script="${DOTFILEDIR}/tasks/install-pins.zsh"
repo="$sandbox/repo"
ai="$sandbox/ai"

export GIT_CONFIG_GLOBAL="$sandbox/gitconfig"; : > "$GIT_CONFIG_GLOBAL"
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# --- the fakes: each answers from $SANDBOX/<kind>/<owner>_<repo>, or fails when it is absent ---
mkdir -p "$sandbox/bin" "$repo/.github/workflows"
print -r -- "#!/bin/sh
case \" \$* \" in
  *' ls-remote '*) for a; do url=\$a; done
    f=\"\$SANDBOX/heads/\$(echo \"\${url#https://github.com/}\" | tr / _)\"
    [ -f \"\$f\" ] && exec cat \"\$f\"; exit 128 ;;
esac
exec $(command -v git) \"\$@\"" > "$sandbox/bin/git"
print -r -- '#!/bin/sh
for a; do url=$a; done
f="$SANDBOX/api/$(echo "${url#https://api.github.com/repos/}" | cut -d/ -f1,2 | tr / _)"
[ -f "$f" ] && exec cat "$f"; exit 22' > "$sandbox/bin/curl"
print -r -- '#!/bin/sh
[ -f "$SANDBOX/softwareupdate" ] && exec cat "$SANDBOX/softwareupdate"; exit 1' > "$sandbox/bin/softwareupdate"
chmod +x "$sandbox/bin/"*

# --- the checkout: three inputs on the 26.05 line; nixpkgs and nix-darwin locked a month ago,
# home-manager a day ago
old=$(( EPOCHSECONDS - 30 * 86400 )) recent=$(( EPOCHSECONDS - 86400 ))
jq -n --argjson old "$old" --argjson recent "$recent" '
  def input(o; r; rev; t; ref): {locked: {type: "github", owner: o, repo: r, rev: rev, lastModified: t},
    original: {type: "github", owner: o, repo: r, ref: ref}};
  {nodes: {nixpkgs: input("NixOS"; "nixpkgs"; "aaa"; $old; "nixos-26.05"),
           "nix-darwin": input("nix-darwin"; "nix-darwin"; "bbb"; $old; "nix-darwin-26.05"),
           "home-manager": input("nix-community"; "home-manager"; "ccc"; $recent; "release-26.05"),
           root: {inputs: {nixpkgs: "nixpkgs", "nix-darwin": "nix-darwin", "home-manager": "home-manager"}}},
   root: "root", version: 7}' > "$repo/flake.lock"
print -r -- '  IMAGE: nixos/nix:2.35.2@sha256:0123' > "$repo/Taskfile.yml"
print -r -- '      - uses: actions/checkout@v7.0.1
      - uses: ./.github/actions/local
      - uses: cachix/install-nix-action@v31.11.1' > "$repo/.github/workflows/ci.yml"

# --- the jshvn/ai checkout: tags 1.0 and 1.1
git init -q -b main "$ai"
git -C "$ai" commit -q --allow-empty -m one && git -C "$ai" tag 1.0
git -C "$ai" commit -q --allow-empty -m two && git -C "$ai" tag 1.1

# fixtures <dir> <nixpkgs heads> <nix-darwin heads> <home-manager heads> <checkout tag> <softwareupdate>
fixtures() {
  rm -rf "$sandbox/fx" && mkdir -p "$sandbox/fx/heads" "$sandbox/fx/api"
  print -r -- "$1" > "$sandbox/fx/heads/NixOS_nixpkgs"
  print -r -- "$2" > "$sandbox/fx/heads/nix-darwin_nix-darwin"
  print -r -- "$3" > "$sandbox/fx/heads/nix-community_home-manager"
  print -r -- "{\"tag_name\": \"$4\"}" > "$sandbox/fx/api/actions_checkout"
  print -r -- '{"tag_name": "v31.11.1"}' > "$sandbox/fx/api/cachix_install-nix-action"
  print -r -- "$5" > "$sandbox/fx/softwareupdate"
}

# run <nix version> <ai ref> -> OUT (stdout and stderr) and CODE
OUT="" CODE=0
run() {
  local declared
  declared=$(jq -n --arg v "$1" --arg ref "$2" --arg dir "$ai" \
    '{nixPackage: "/nix/store/h-nix-\($v)", dotfiles: {profile: "personal",
      apps: {"claude-code": {enable: true, ref: $ref, dir: $dir}}}}')
  CODE=0
  OUT=$(SANDBOX="$sandbox/fx" PATH="$sandbox/bin:$PATH" DOTFILEDIR="$repo" zsh "$script" <<< "$declared" 2>&1) || CODE=$?
}

# expect <label> <pattern> [absent]: OUT matches (or, with "absent", does not match) and CODE is 0
expect() {
  local hit=0 want=1
  grep -qE -- "$2" <<< "$OUT" && hit=1
  [[ "${3:-}" == absent ]] && want=0
  if (( CODE == 0 && hit == want )); then
    check "install-pins.$1"
  else
    cross "install-pins.$1: expected exit 0 and ${3:-present} /$2/ (exit=$CODE)"
    print -r -- "$OUT" | sed 's/^/      /'
    failures=$(( failures + 1 ))
  fi
}

T=$'\t'
none='Software Update Tool

Finding available software
No new software available.'

# 1. Every pin current: home-manager is behind but locked a day ago; only nixpkgs has cut 26.11.
fixtures "aaa${T}refs/heads/nixos-26.05
fff${T}refs/heads/nixos-26.05-small
eee${T}refs/heads/nixos-26.11" \
  "bbb${T}refs/heads/nix-darwin-26.05" \
  "ddd${T}refs/heads/release-26.05" \
  v7.0.1 "$none"
run 2.35.2 1.1
expect current.all "all current"
expect current.no-warning "WARN" absent

# 2. Every pin stale: nixpkgs behind and a month old; home-manager behind but recent; all three
# have cut 26.11; Nix moved past the image; a newer checkout release; a macOS update; ai on 1.0.
available='Software Update Tool

Finding available software
Software Update found the following new or updated software:
* Label: macOS Golden Gate 27.0.1-27A400
	Title: macOS Golden Gate 27.0.1, Version: 27.0.1, Size: 4194304KiB, Recommended: YES, Action: restart,'
fixtures "zzz${T}refs/heads/nixos-26.05
eee${T}refs/heads/nixos-26.11" \
  "bbb${T}refs/heads/nix-darwin-26.05
ggg${T}refs/heads/nix-darwin-26.11" \
  "ddd${T}refs/heads/release-26.05
hhh${T}refs/heads/release-26.11" \
  v7.1.0 "$available"
run 2.36.0 1.0
expect stale.lock "flake.lock.*nixpkgs"
expect stale.lock-recent-input "flake.lock.*home-manager" absent
expect stale.lock-bump "nix flake update"
expect stale.release "26\.11.*flake\.nix|flake\.nix.*26\.11"
expect stale.image "nixos/nix:2\.35\.2.*2\.36\.0"
expect stale.image-bump "hub\.docker\.com/v2/repositories/nixos/nix/tags/2\.36\.0"
expect stale.action "actions/checkout@v7\.0\.1.*v7\.1\.0"
expect stale.action-current "cachix" absent
expect stale.macos "macOS Golden Gate 27\.0\.1-27A400"
expect stale.ai "jshvn/ai.*1\.0.*1\.1"
expect stale.ai-bump "profiles/personal/default\.nix"
expect stale.not-all-current "all current" absent

# 3. No network: every lookup fails; the warning says so and the install is not failed.
rm -rf "$sandbox/fx" && mkdir -p "$sandbox/fx"
run 2.35.2 1.1
expect offline.flake "could not check flake\.lock"
expect offline.actions "could not check actions/checkout"
expect offline.macos "could not check macOS"
expect offline.not-all-current "all current" absent

if (( failures == 0 )); then
  success "install-pins: all scenarios passed"
else
  error "install-pins: ${failures} scenario(s) failed"
fi
exit "$failures"
