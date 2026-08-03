# Custom Agents

Repo-owned agents, symlinked as a directory into
`~/.config/claude/agents/`.

`ecc/` is a machine-local link into the everything-claude-code payload,
pruned by that addon to a curated keep-list (see
`manifests/claude-addons/ecc.toml`); it is excluded from the repo via
`.git/info/exclude`. Custom agents placed here take preference over
everything-claude-code when both cover the same use case. Build agents here
for workflows specific to this dotfiles setup or personal projects.
