#!/bin/zsh

# =============================================================================
# tasks/audit-brew-cleanup.zsh -- what `brew bundle cleanup` would uninstall
#
# Purpose:      Read the dry-run output of `brew bundle cleanup --file=<Brewfile>`
#               (run without a terminal, so it never prompts) on stdin and print
#               one "<kind><TAB><name>" line per item it would uninstall or
#               untap. Only the "Would uninstall <kind>:" and "Would untap:"
#               sections count: brew's cache housekeeping ("Would `brew
#               cleanup`:"), its closing "Run ..." line and any update report
#               before the sections are not drift. Brew prints one item per
#               line when stdout is not a terminal, and an item may hold spaces
#               (an App Store app is "<name> (<id>)"), so each line is one item.
# Depends on:   awk.
# Side effects: none.
# =============================================================================

set -euo pipefail

awk '
  /^Would uninstall .*:$/ { kind = substr($0, 17, length($0) - 17); next }
  /^Would untap:$/        { kind = "taps"; next }
  /^(Would|Run) /         { kind = ""; next }
  kind != "" && NF        { gsub(/^[ \t]+|[ \t]+$/, ""); print kind "\t" $0 }
'
