#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05f-sw_vers-warn/probe.zsh
#
# Positive fixture for LINT-05: portability hint for sw_vers invocation.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
sw_vers -productVersion
