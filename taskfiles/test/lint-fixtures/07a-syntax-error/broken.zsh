#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/07a-syntax-error/broken.zsh
#
# Positive fixture for LINT-07: deliberate zsh -n parse error.
# The unterminated [[ causes zsh -n to exit non-zero with a parse error.
#
# Expected outcome: LINT-07 fires (expect: fail)
# -----------------------------------------------------------------------------

set -euo pipefail
if [[ "$1" == "test"
  echo "missing closing bracket"
fi
