#!/bin/zsh
# fixture: hardcoded prefix exempted by a same-line lint-allow annotation.
ARCH_PREFIX="/opt/homebrew" # lint-allow: hardcoded-prefix
echo "$ARCH_PREFIX"
