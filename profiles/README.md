# profiles

A profile contains the configuration for one type of laptop. It sets each choice that the
modules leave open. It also contains the identity that the laptop uses to sign and connect.
Each profile has one directory. Each machine file imports one profile.

| File | Link | Linked by |
|------|------|-----------|
| `default.nix` | None. The machine file imports it. | `machines/<name>.nix` |
| `git` | `~/.config/git/profile`. Contains the email. Turns on commit and tag signing. `apps/git/config` includes it for repositories under `~/git/`. | `apps/git/` |
| `ssh` | `~/.ssh/profile`. Contains the host blocks. `apps/ssh/config` includes it. | `apps/ssh/` |
| `key.pub` | `~/.ssh/profile.pub`. Contains the public key. `git` signs with this key. `ssh` pins it. | `apps/ssh/` |
| `agent.toml` | `~/.config/1Password/ssh/agent.toml`. Selects the keys that the agent offers. | `apps/1password/` |

A profile directory must contain only these files. `profiles/.gitignore` ignores all other
files, so a private key that you copy in by mistake does not get committed. `task validate`
reports a failure for each other file. Keep private keys in 1Password.

`default.nix` sets these options under `dotfiles`:

- `profile` is the name of the profile directory. Its type is an enum of the directories
  here. Thus an incorrect name causes the evaluation to fail.
- `system.<concern>` is true or false. Set it for each concern in `system/`.
- `apps.<name>.enable` is true or false. Set it for each optional app in `apps/`.
- Some apps have more options:
  - `raycast.freeCmdSpace` turns off the Spotlight Cmd+Space shortcut.
  - `vscode.extensions` adds extensions to the bundled set. This option is optional.
  - `vscode.vsix` adds extensions from a VSIX. This option is optional.
  - `claude-code.profile` and `claude-code.ref` select the jshvn/ai profile and ref. Set
    both when claude-code is on. `claude-code.profile` is a profile in jshvn/ai, not a
    profile here.
- `shell.jgrid-net` turns on the fleet aliases for jgrid.net.
- `repo.devToolchain` installs the linters, the formatters and hyperfine. You need these
  tools to work on this repository.
- `packages.formulae`, `packages.casks` and `packages.mas` list the free choices. These are
  packages with no configuration.
  - Do not list a package that the base or an enabled app supplies. If you do, an assertion
    fails.
  - Do not list a tap. The package name supplies the tap. For example,
    `hashicorp/tap/terraform` adds the `hashicorp/tap` tap.

Each option above has no default, except the two optional `vscode` options. If a profile does
not set an option, the evaluation fails and shows the name of the option. Thus each new
concern or app needs a decision in each profile.

The `work/` profile has no machine file yet. `flake.nix` evaluates it with a synthetic
machine. This keeps the profile correct. When you add an option, set it in `work/` too. When
the work laptop is in scope, add its email and its `key.pub`.

## Add a profile

1. Copy an existing directory to `profiles/<name>/`.
2. In `default.nix`, set `profile = "<name>"`.
3. In `git`, set the email.
4. In `ssh`, set the host blocks.
5. In `key.pub`, put the public key. Copy the key from the 1Password item.
6. In `agent.toml`, set the 1Password item.
7. Enter `git add profiles/<name>`.
8. Enter `task check`.
9. Import the profile in a machine file. See `machines/README.md`.
