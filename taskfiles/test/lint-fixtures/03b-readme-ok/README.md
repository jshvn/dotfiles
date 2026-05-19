<!--
taskfiles/test/lint-fixtures/03b-readme-ok/README.md

Negative fixture for LINT-03b: markdown prose may mention `ln -s`
inside backticks (documenting the rule) without tripping it. The
production scan is scoped to *.yml (and excludes test/), so this
file -- and the project's real taskfiles/README.md -- must never
flag.

Expected outcome: LINT-03b does not fire (expect: pass)
-->

# Documentation mentioning the rule

LINT-03b forbids bare `ln -s` outside `helpers.yml`. The wrapper is
`_:safe-link`. Use it instead of `ln -s` directly.
