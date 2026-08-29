---
name: jshvn-one-check-rule
description: Use when finishing non-trivial logic and deciding what verification to leave behind - what counts as the one check, what is exempt, and why frameworks and fixtures are the wrong reach. Fires on "does this need a test", "what should I test here".
---

# The One-Check Rule

Lazy code without its check is unfinished.

Non-trivial logic leaves exactly one runnable check behind: the smallest thing that fails
if the logic breaks. An assert-based self-check, or one small test file. No frameworks,
no fixtures, no harness. Trivial one-liners need nothing.

## What counts as the one check

The check has to be able to fail for the reason the logic could be wrong. That is the
whole bar, and it rules out most of what gets written reflexively:

| Not a check | Why |
|---|---|
| Asserting the function returns without throwing | Passes when the answer is wrong |
| Asserting on a mock you configured in the same test | Tests the mock |
| A snapshot of current output | Locks in the bug if there is one |
| Three tests of the same happy path | Still one check, written thrice |

A good one-check picks the input where the logic is most likely to be wrong -- the empty
case, the boundary, the branch that only fires on a second run -- not the input that best
demonstrates the feature.

## What is exempt

- Trivial one-liners with no branching
- Interactive convenience code -- shell functions, aliases, a prompt helper. A parse-check
  plus running it once live is its verification. Writing smoke tests for these costs more
  than it catches.
- Pure glue with no logic of its own: a re-export, a thin argument-forwarding wrapper

The rule targets logic where a silent break corrupts state or output that something else
depends on. That is where one check pays for itself and where its absence is expensive.

## Why not more

More checks are not free: they are code that has to be read, kept true, and updated every
time the logic moves. The second and third check on the same logic mostly duplicate the
first's coverage while tripling what a future change has to keep green. One check that can
actually fail beats a suite that cannot.

Where a repo already has a test suite and a runner, wire the check into it rather than
inventing a parallel mechanism -- the aggregate command is the point.
