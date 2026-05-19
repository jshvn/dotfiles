#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05c-osascript-warn/notify.zsh
#
# Positive fixture for LINT-05: portability hint for osascript invocation.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
osascript -e 'display notification "test" with title "hello"'
