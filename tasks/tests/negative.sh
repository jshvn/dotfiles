#!/usr/bin/env bash
# tasks/tests/negative.sh -- the resolver rules, proven by breaking them
#
# Purpose:      Mutate a copy of profiles/personal.nix three ways (an app left
#               unaccounted, a cask the registry already provides, a bundled
#               VS Code extension listed again) and require each evaluation of
#               the lerasium machine to fail with the expected message. Runs
#               inside the nix image (`task test`), with the repo at $SRC.
# Depends on:   nix (flakes); bash; SRC env var (default /work).
# Side effects: copies under the container's /tmp only.
set -uo pipefail
SRC="${SRC:-/work}"
MACHINE="${MACHINE:-lerasium}"
failed=0

probe() { # probe NAME OLD NEW EXPECTED-SUBSTRING
  local name="$1" old="$2" new="$3" want="$4" f c out
  rm -rf "/tmp/$name" && cp -r "$SRC" "/tmp/$name"
  f="/tmp/$name/profiles/personal.nix"
  c=$(cat "$f")
  if [ "${c//"$old"/$new}" = "$c" ]; then
    echo "  x $name: mutation '$old' matched nothing in profiles/personal.nix"
    failed=1
    return
  fi
  printf '%s\n' "${c//"$old"/$new}" > "$f"
  out=$(nix eval --raw "path:/tmp/$name#darwinConfigurations.$MACHINE.config.system.build.toplevel.drvPath" 2>&1)
  if [ $? -ne 0 ] && grep -qF -- "$want" <<< "$out"; then
    echo "  ok $name: fails with '$want'"
  else
    echo "  x $name: expected a failure mentioning '$want'"
    echo "$out" | grep -E 'error|assert' | head -5 | sed 's/^/      /'
    failed=1
  fi
}

probe unaccounted-app 'herdr.enable = true;' '# herdr omitted' "dotfiles.apps.herdr.enable' was accessed but has no value"
probe redundant-cask '"1password-cli"' '"1password-cli" "raycast"' 'packages.casks lists what base or an enabled app already provides: raycast'
probe vscode-overlap 'extensions = [ "golang.go" ];' 'extensions = [ "golang.go" "biomejs.biome" ];' 'apps.vscode.extensions lists what the app already bundles: biomejs.biome'

exit $failed
