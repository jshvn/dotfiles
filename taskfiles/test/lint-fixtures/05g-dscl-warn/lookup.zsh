#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05g-dscl-warn/lookup.zsh
#
# Positive fixture for LINT-05: portability hint for dscl invocation.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
dscl . -read "/Users/$USER" UserShell
