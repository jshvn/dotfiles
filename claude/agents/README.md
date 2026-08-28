# Custom Agents

Repo-owned agents, symlinked as a directory into
`~/.config/claude/agents/`.

`ecc/` is a machine-local directory of links into the everything-claude-code
payload, one per name on that addon's agent keep-list (see
`manifests/claude-addons/ecc.toml`); it is excluded from the repo via
`.git/info/exclude`. Every linked agent's description loads into every
session, so the link set is a context budget. Custom agents placed here take preference over
everything-claude-code when both cover the same use case. Build agents here
for workflows specific to this dotfiles setup or personal projects.
