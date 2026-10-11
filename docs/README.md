# docs

This directory contains reference material. Each other directory has a README for its own
contents. This directory contains the material that applies to more than one directory.

- `SECURITY.md` describes the trust chain of the bootstrap. The chain includes Nix, go-task
  and Homebrew.
- `MACHINES.md` describes the purpose, the hardware and the role of each machine.
- `DECISIONS.md` contains the locked decisions and the scope limits. It also contains the
  performance constraints and the security constraints.

The option declarations in `modules/`, `system/` and `apps/` are the schema of the
configuration. `task show` shows the evaluated configuration of a machine.

Do not keep design records or implementation plans here. If a decision is important, write it
in `DECISIONS.md`. The git history keeps all other records.
