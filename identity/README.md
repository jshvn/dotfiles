# identity

Git and SSH identity. A profile sets `dotfiles.identity` to `personal`, `work` or `none`
(`modules/identity.nix`); the switch links the matching overlays, and a real identity turns
the 1Password app on (its agent config lives in `apps/1password/`). Swapping identities is a
relink, not an edit. No logic branches on platform here, only on identity.

## Key files

- `git/config` -- main git config; linked to `~/.config/git/config`. Carries the
  `[includeIf "gitdir/i:~/git/personal/"]`, `[includeIf "gitdir/i:~/git/katoptra/"]` (same
  personal overlay) and `[includeIf "gitdir/i:~/git/work/"]` blocks.
- `git/ignore` -- global gitignore, referenced via `core.excludesfile = ignore`.
- `git/identities/<name>` -- per-identity overlays; the directory is linked to
  `~/.config/git/identities`, so every overlay is present and `includeIf` picks one.
- `ssh/config` -- main SSH config; linked to `~/.ssh/config`. One
  `Include ~/.ssh/identities/active` directive, no `Match exec`.
- `ssh/identities/<name>` -- per-identity host configs. The selected one is linked to
  `~/.ssh/identities/active`; the others are not deployed.
- `ssh/keys/<name>.pub` -- public keys only; the directory is linked to
  `~/.ssh/identities/keys`. Private keys never enter the repo: `keys/.gitignore` allowlists
  `*.pub`, and `task validate` crosses on anything else.
- `ssh/cloudflared.zsh` -- ProxyCommand wrapper for the `*-*.jgrid.net` tunnel hostnames and
  `*.plex.me`; linked to `~/.ssh/identities/cloudflared.zsh` on every machine.

The links are the entries `modules/identity.nix` adds to `dotfiles.links`; `task validate`
reads each back and checks the git `user.email` under `~/git/<identity>`, the 1Password agent
socket and `ssh-add -L`.

## Adding an identity

1. Create `git/identities/<name>` and `ssh/identities/<name>`.
2. Add `<name>` to the `dotfiles.identity` enum in `modules/identity.nix`. A real identity
   routes through the 1Password agent (`IdentityAgent` in the ssh overlay, `op-ssh-sign` in
   the git overlay) and turns the app on; `none` turns it off.
3. Set `dotfiles.identity = "<name>"` in the profile that wants it; `task install`, then
   `task validate`.
