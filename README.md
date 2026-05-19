# Dotfiles

macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.

## Install

```zsh
git clone <repo-url>
./bootstrap.zsh
task setup -- <machine-name>
task install
```

`bootstrap.zsh` acquires Homebrew, go-task, and yq. `task setup` writes the
active machine name to `$XDG_STATE_HOME/dotfiles/machine`; `task install` runs
the full install pipeline. For the list of accepted `<machine-name>` values,
see `docs/MACHINES.md`.

## Common Tasks

The five top-level commands are:

| Command          | Purpose                                                |
|------------------|--------------------------------------------------------|
| `task install`   | Install dotfiles for the active machine                |
| `task setup`     | Set the active machine: `task setup -- <machine-name>` |
| `task validate`  | Validate full installation state                       |
| `task test`      | Run all smoke tests                                    |
| `task lint`      | Run all lint checks                                    |

Run `task` (no arguments) to see the curated task surface; `task --list` for
the full graph.

## Where things live

- `docs/MANIFEST.md` -- manifest schema, inheritance rules, worked examples
- `docs/SECURITY.md` -- bootstrap trust chain
- `docs/MACHINES.md` -- per-machine purpose and hardware

## Contributing

See [CLAUDE.md](CLAUDE.md) for conventions, rules, where-to-add tables, and
the lint catalogue.
