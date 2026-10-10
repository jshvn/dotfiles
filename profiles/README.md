# profiles

A profile is what a kind of laptop wants and who it is: every choice the modules leave open,
and the identity it signs and connects as. One directory per profile; a machine file imports
exactly one.

| File | Linked to | By |
|------|-----------|----|
| `default.nix` | (imported by the machine file) | `machines/<name>.nix` |
| `git` | `~/.config/git/profile`: email, signing key; `apps/git/config` includes it under `~/git/` | `apps/git/` |
| `ssh` | `~/.ssh/profile`: host blocks; `apps/ssh/config` includes it | `apps/ssh/` |
| `key.pub` | `~/.ssh/profile.pub`: the public key; `git` signs with it, `ssh` pins it | `apps/ssh/` |
| `agent.toml` | `~/.config/1Password/ssh/agent.toml`: which keys the agent offers | `apps/1password/` |

Nothing else may live in a profile directory: `profiles/.gitignore` ignores any other file
(a private key copied in by mistake), and `task validate` crosses on it. Private keys stay in
1Password.

`default.nix` sets, under `dotfiles`:

- `profile`: its own directory name. The type is an enum of the directories here, so a typo
  fails evaluation.
- `system.<concern>`: true or false for every file in `system/` (dock, finder, input,
  screenshots, security, appearance, display, animations).
- `apps.<name>.enable`: true or false for every optional app in `apps/` (raycast, ghostty,
  herdr, vscode, claude-code, conda, dust), plus the app's own knobs: `raycast.freeCmdSpace`,
  `vscode.extensions` (extras beyond the bundled set), `claude-code.profile` and `.ref` (both,
  when enabled). `claude-code.profile` names a profile in jshvn/ai, not one here.
- `shell.jgrid-net`: the jgrid.net fleet aliases.
- `repo.devToolchain`: linters, formatters and hyperfine for working on this repo.
- `packages.formulae`, `packages.casks`, `packages.mas`: free choices with no configuration
  attached. Not what base or an enabled app already provides (an assertion fails), and never
  a tap: `hashicorp/tap/terraform` implies its tap.

Every switch above has no default. Leave one out and evaluation fails naming it; that is how a
new concern or app is forced to be a decision on every profile.

`work/` has no machine file yet; `flake.nix` evaluates it under a synthetic machine so it
cannot rot. Keep it current when adding a switch. Its email and `key.pub` are filled in when
the work laptop comes into scope.

## Adding a profile

1. Copy an existing directory to `profiles/<name>/` and set `profile = "<name>"`.
2. Set its email in `git`, its host blocks in `ssh`, its public key in `key.pub` (copy it from
   the 1Password item), and the item in `agent.toml`.
3. `git add` it, `task check`; then a machine file imports it (`machines/README.md`).
