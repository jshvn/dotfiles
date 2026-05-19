#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/04a-missing-set-euo/script.zsh
#
# Positive fixture for LINT-04: executable .zsh with only set -e.
# This is the bootstrap.zsh:2 bug class -- set -e alone silently ignores
# unbound variables (-u) and mid-pipeline failures (-o pipefail).
# LINT-04 checks for executable .zsh files and requires set -euo pipefail.
#
# Expected outcome: LINT-04 fires (expect: fail)
# -----------------------------------------------------------------------------

set -e
echo "running"
