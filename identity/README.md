# identity

Phase 4 owns git + SSH identity. Manifest-driven: per-machine TOML files
declare `identity.git` and `identity.ssh` as the basename of any file under
`identity/git/identities/` and `identity/ssh/identities/` respectively
(filesystem-driven enum — drop a file, the resolver picks it up).
The gates `features.one-password-ssh`, `features.one-password-signing`, and
`features.server-include` further shape per-machine behavior. macOS-only
(Apple Silicon + Intel); the model would carry cleanly to other platforms
because no logic branches on platform here -- only on identity. Symlinks
deploy via `taskfiles/identity.yml` and `_:safe-link`; the active SSH
identity is selected by a single symlink swap rather than profile-file-exec.

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
  `taskfiles/identity.yml` materializes when `features.server-include = true`.
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
  `features.one-password-ssh = true`.
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
edit is needed. Add a cross-field rule to `install/resolver.zsh`
`validate_manifest()` only if the new identity carries 1Password directives
(the `personal|work` case statements gate the `one-password-*` features). If
you add such a rule, cover it with a negative fixture under
`manifests/test/fixtures/_invalid-*/` so `task test:manifest` verifies it.
Update `docs/MANIFEST.md` `identity.*` Allowed-values columns.

**A machine.** Create `manifests/machines/<name>.toml`, then
`task setup -- <name>`. Set `identity.git` and `identity.ssh` to the desired
values from the enum.

**A 1Password-gated feature.** Add the kebab-case key to
`manifests/defaults.toml` `[features]` with `false`. Set `true` in the
relevant machine TOMLs. Add a cross-field validation rule in
`install/resolver.zsh validate_manifest()` if the new flag should imply or be
implied by an identity value. Cover it with a negative fixture.

## References

- `../docs/MANIFEST.md` -- manifest schema and merge semantics (Phase 1)
- `../CLAUDE.md` -- v2 conventions (status-block templating, `_:safe-link`,
  no AI attribution, no emojis)
