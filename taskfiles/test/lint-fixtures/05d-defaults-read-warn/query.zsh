#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05d-defaults-read-warn/query.zsh
#
# Positive fixture for LINT-05: portability hint for `defaults read`.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
defaults read com.apple.dock orientation
