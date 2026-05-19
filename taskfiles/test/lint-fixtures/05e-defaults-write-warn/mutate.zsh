#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05e-defaults-write-warn/mutate.zsh
#
# Positive fixture for LINT-05: portability hint for `defaults write`.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
defaults write com.apple.dock orientation -string bottom
