#!/bin/zsh
# -----------------------------------------------------------------------------
# taskfiles/test/lint-fixtures/05h-plistbuddy-warn/edit-plist.zsh
#
# Positive fixture for LINT-05: portability hint for PlistBuddy invocation.
# See 05a-pbcopy-warn for rule details.
#
# Expected outcome: LINT-05 warns but exits 0 (expect: warn)
# -----------------------------------------------------------------------------

set -euo pipefail
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /tmp/test.plist
