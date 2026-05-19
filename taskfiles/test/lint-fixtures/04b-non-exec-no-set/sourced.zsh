#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/04b-non-exec-no-set/sourced.zsh
#
# Negative fixture for LINT-04: non-executable .zsh with no set line.
# Sourced-only files (aliases, functions, completions) are exempt from the
# set -euo pipefail requirement -- LINT-04 filters via -perm +111.
# This file must NOT be flagged.
#
# Expected outcome: LINT-04 does not fire (expect: pass)
# -----------------------------------------------------------------------------

function my_alias_fn() { echo "called"; }
