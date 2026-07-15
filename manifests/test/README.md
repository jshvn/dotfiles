# manifests/test

Test fixtures for the resolver (`install/resolver.zsh`).

Fixture families under `fixtures/`:

- `typed-NN-*/` -- positive fixtures. Each contains a v2 `machine.toml`, an
  `expected.json`, and optionally a `features.toml` registry override; the
  driver runs the resolver and diffs its output against `expected.json`.
- `_invalid-*/` -- negative fixtures. Each holds a `machine.toml` (plus an
  optional `features.toml`) and an `expect.txt` whose first line is a substring
  expected in the resolver's validation error; the expected outcome is a
  non-zero exit.

A fixture that exercises feature-registry validation ships its own minimal
`features.toml` (passed via `--registry`); package-only fixtures ship an empty
registry so they need not enumerate the production flags.

`shared/` holds the shared bundle TOMLs (`dotfiles.toml`, `util.toml`,
`extbundle.toml`, `extras.toml`) that the fixtures reference via `--shared-dir`.

Run from the repo root:

    task test
