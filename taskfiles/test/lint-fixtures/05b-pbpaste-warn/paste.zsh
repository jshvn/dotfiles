#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05b-pbpaste-warn/paste.zsh
#
# Positive fixture for LINT-05: portability hint for pbpaste invocation.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
pbpaste > /tmp/clipboard.txt
