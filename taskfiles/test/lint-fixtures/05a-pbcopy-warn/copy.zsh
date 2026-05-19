#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05a-pbcopy-warn/copy.zsh
#
# Positive fixture for LINT-05: portability hint for pbcopy invocation.
# LINT-05 is warn-only and always exits 0 -- it flags macOS-specific commands
# that will need porting when Linux support is added in a future version.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
echo "$1" | pbcopy
