# identity

Phase 4 owns git + SSH identity. Manifest-driven: each machine's `[machine]`
table declares a single `identity` scalar -- the basename of a file that must
exist under both `identity/git/identities/` and `identity/ssh/identities/`
(filesystem-driven enum — drop a file in each, the resolver picks it up).
The gates `features.one-password-ssh`, `features.one-password-signing`, and
`features.server-include` further shape per-machine behavior. macOS-only
(Apple Silicon + Intel); the model would carry cleanly to other platforms
because no logic branches on platform here -- only on identity. Symlinks
deploy via `taskfiles/identity.yml` and `_:safe-link`; the active SSH
identity is selected by a single symlink swap.

## Key files

- `git/config` -- main git config; symlinked to `~/.config/git/config`. Carries
  the workstation `[includeIf "gitdir/i:~/git/personal/"]` and
  `[includeIf "gitdir/i:~/git/work/"]` blocks plus the universal
  `[include] path = server-include.config` hook (absent on workstations
  is a silent no-op).
- `git/ignore` -- global gitignore, referenced via `core.excludesfile = ignore`.
- `git/identities/<name>` -- flat per-identity overlays. Workstation overlays
  are loaded via the `[includeIf gitdir/i:...]` blocks in `git/config`; server
  overlays are loaded via the `server-include.config` wildcard that
  `taskfiles/identity.yml` materializes when the `server-include` feature is
  enabled.
- `ssh/config` -- main SSH config; symlinked to `~/.ssh/config`. Contains a
  single `Include ~/.ssh/identities/active` directive; no `Match exec`
  blocks. Identity is resolved at install time, not connection time.
- `ssh/identities/<name>` -- flat per-identity host configs; deployed at
  `~/.ssh/identities/<name>` on every machine. Swapping identities is
  a relink, not an edit.
- `ssh/identities/active` -- symlink to the manifest-selected identity file.
  Created by `taskfiles/identity.yml`'s ssh task.
- `ssh/agent.toml` -- 1Password SSH agent key-order config; symlinked to
  `~/.config/1Password/ssh/agent.toml` by `taskfiles/identity.yml` when
  the `one-password-ssh` feature is enabled.
- `ssh/keys/<name>.pub` -- public keys only. Private keys NEVER enter the
  repo (IDNT-06); the `keys/.gitignore` allowlist (`*` + `!*.pub` +
  `!.gitignore`) is the enforcement.
- `ssh/cloudflared.zsh` -- ProxyCommand wrapper invoked by the personal
  identity's `ProxyCommand` directive for `*.jgrid.net` and `*.plex.me` hosts.
  Deployed on every machine even though only the personal identity
  references it.

## Adding a pattern

**An identity.** Create `git/identities/<name>` and `ssh/identities/<name>`.
The resolver is filesystem-driven -- it accepts any identity whose file exists
under `identity/git/identities/` and `identity/ssh/identities/`, so no enum
edit is needed. If the new identity carries 1Password directives, mark the
overlay with a capability sentinel comment (`# capability: one-password-ssh`
in the ssh overlay, `# capability: one-password-signing` in the git overlay);
`install/resolver.zsh validate_manifest()` then requires any machine using
that identity to enable the matching feature. Cover a new sentinel with a
negative fixture under `manifests/test/fixtures/_invalid-*/` so
`task test:manifest` verifies it. Update `docs/MANIFEST.md`
`machine.identity` allowed-values.

**A machine.** Create `manifests/machines/<name>.toml`, then
`task setup -- <name>`. Set `identity` in the `[machine]` table to the desired
overlay name.

**A 1Password-gated feature.** Register the kebab-case key as a `[<key>]`
block in `manifests/features.toml`, then list it in every machine's
`[features]` enabled or disabled array. Add a cross-field validation rule in
`install/resolver.zsh validate_manifest()` if the new flag should imply or be
implied by an identity value. Cover it with a negative fixture.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics (Phase 1)
- `../CLAUDE.md` -- project conventions (status-block templating, `_:safe-link`,
  no AI attribution, no emojis)
