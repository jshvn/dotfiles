# Custom Skills

Using `everything-claude-code` skills as the default set.

Custom skills placed here take preference over everything-claude-code
when both cover the same use case. Build skills here for workflows
specific to this dotfiles setup or personal projects.

Local skills currently present:

- `context-dump/` -- print a structured dump of everything loaded in the
  current context (identity, instructions, tools, skills, session state).
- `goalsmith/` -- interview the user to forge a complete,
  transcript-verifiable goal for the built-in `/goal` command.
