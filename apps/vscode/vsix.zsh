#!/bin/zsh

# =============================================================================
# apps/vscode/vsix.zsh -- install VS Code extensions from VSIX files in git repos
#
# Purpose:      Takes "<id> <remote>" argument pairs. For each, shallow-clones
#               <remote> and installs <name>.vsix from its root (<name> is
#               <id> after the publisher) with `code --install-extension`,
#               unless the version inside that VSIX is the one installed.
#               Invoked by the apps/vscode activation step, as the user.
# Depends on:   git (SSH, non-interactive); code; unzip; jq; tasks/messages.zsh
#               ($MESSAGES, else relative to this script).
# Side effects: a temp clone per extension, removed on exit; installs or
#               replaces VS Code extensions.
# =============================================================================

set -euo pipefail

source "${MESSAGES:-${0:A:h}/../../tasks/messages.zsh}"

# Non-interactive git: no credential prompts, a capped SSH handshake, so an
# offline machine fails fast instead of hanging.
export GIT_TERMINAL_PROMPT=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
installed=$(code --list-extensions --show-versions)

for id remote in "$@"; do
  git -c core.sshCommand='ssh -o BatchMode=yes -o ConnectTimeout=5' \
    clone --quiet --depth 1 "$remote" "$tmp/$id"
  vsix="$tmp/$id/${id#*.}.vsix"
  version=$(unzip -p "$vsix" extension/package.json | jq -r .version)
  if grep -qix "$id@$version" <<< "$installed"; then
    continue
  fi
  info "vscode: installing $id@$version from $remote"
  # --force: the committed VSIX wins, even over a newer version installed by hand
  code --install-extension "$vsix" --force >/dev/null
done
