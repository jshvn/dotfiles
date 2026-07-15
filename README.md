# 👨🏻‍💻 Josh's dotfiles

[![ci](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/jshvn/dotfiles/actions/workflows/ci.yml)

macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.

##  Install or update

### Install
```zsh
$ git clone https://github.com/jshvn/dotfiles.git
$ ./bootstrap.zsh
$ task setup -- <machine-name>
$ task install
```

### Update
```zsh
$ update
```
`update` fast-forwards the repo from its remote (`task repo:sync`), then runs `task install`.
The pull is fast-forward-only and skips cleanly -- with a warning, never blocking the install --
on a dirty working tree, a diverged branch, or when offline / SSH auth is unavailable. Set
`repo-auto-update = false` in a machine manifest to skip the pull entirely.

## ⚙️ Common Tasks

The six top-level commands are:

| Command          | Purpose                                                |
|------------------|--------------------------------------------------------|
| `task install`   | Install dotfiles for the active machine                |
| `task setup`     | Set the active machine: `task setup -- <machine-name>` |
| `task validate`  | Validate full installation state                       |
| `task test`      | Run all smoke tests                                    |
| `task lint`      | Run all lint checks                                    |
| `task audit`     | Detect drift across all domains (read-only)            |

Run `task` (no arguments) to see the curated task surface; `task --list` for
the full graph.

## 📦 Where things live

- `docs/MANIFEST.md` -- manifest schema, inheritance rules, worked examples
- `docs/SECURITY.md` -- bootstrap trust chain
- `docs/MACHINES.md` -- per-machine purpose and hardware

## 🧑🏻 Contributing

See [CLAUDE.md](CLAUDE.md) for conventions, rules, where-to-add tables, and
the lint catalogue.
