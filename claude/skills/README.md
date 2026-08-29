# Custom Skills

Repo-owned skills, symlinked as a directory into
`~/.config/claude/skills/`.

Alongside them sit machine-local symlinks into the everything-claude-code
payload -- the addon's keep-list, excluded from the repo via
`.git/info/exclude`. Every linked skill's description loads into every
session, so the link set is a context budget. Custom skills placed here take
preference over everything-claude-code when both cover the same use case.

Repo-owned skills:

- `jshvn-context-dump/` -- print a structured dump of everything loaded in the
  current context (identity, instructions, tools, skills, session state).
- `jshvn-goalsmith/` -- interview the user to forge a complete,
  transcript-verifiable goal for the built-in `/goal` command.
- `jshvn-verifying-dotfiles-changes/` -- map a change in this repo to the task
  commands that prove it converged; the five-tier model and one-check rule.
