# Custom Skills

Repo-owned skills, symlinked as a directory into
`~/.config/claude/skills/`.

Alongside them sit machine-local symlinks into the everything-claude-code
payload -- the addon's keep-list, excluded from the repo via
`.git/info/exclude`. Every linked skill's description loads into every
session, so the link set is a context budget. Custom skills placed here take
preference over everything-claude-code when both cover the same use case.

Repo-owned skills:

- `jshvn-containerized-toolchain/` -- cross-repo container defaults: engine detection,
  base-image choice, the arch gotcha, the `run` task, and the converged end state.
- `jshvn-context-dump/` -- print a structured dump of everything loaded in the
  current context (identity, instructions, tools, skills, session state).
- `jshvn-goalsmith/` -- interview the user to forge a complete,
  transcript-verifiable goal for the built-in `/goal` command.
- `jshvn-one-check-rule/` -- what verification non-trivial logic leaves behind,
  what counts as a check, and what is exempt.
- `jshvn-replacing-a-system/` -- the purge pass that clears every trace of a replaced
  system from comments and docs before the commit lands.
- `jshvn-taskfile-conventions/` -- go-task over make: the banner-as-`default`-task pattern,
  grouping by effect, task conventions, and the converged end state.
- `jshvn-typescript-conventions/` -- Biome and tsconfig core, the Taskfile-over-npm-scripts
  operator surface, and the converged end state.
- `jshvn-verifying-dotfiles-changes/` -- map a change in this repo to the task
  commands that prove it converged; the five-tier model and one-check rule.
