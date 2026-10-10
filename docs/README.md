# docs

Reference material. Per-directory READMEs cover their own directory; this
directory holds what spans several.

- `SECURITY.md` -- bootstrap trust chain (Nix, go-task, Homebrew)
- `MACHINES.md` -- per-machine prose (purpose, hardware, role)
- `DECISIONS.md` -- locked decisions, scope boundaries, performance/security constraints

The declaration's schema is the option declarations in `modules/`, `system/` and `apps/`;
`task show` prints a machine's evaluated declaration.

Design records and implementation plans are not kept here. A decision worth
preserving goes into `DECISIONS.md`; everything else is git history.
