# manifests/test

Golden-output test fixtures for the deep-merge resolver (`install/resolver.zsh`).

Fixture families under `fixtures/`:

- `0N-*/` (merge) and `typed-NN-*/` (typed package-bucket merge) -- positive
  fixtures. Each contains `defaults.toml`, `machine.toml`, and `expected.json`;
  the driver merges the two TOMLs and diffs the result against `expected.json`.
- `_invalid-*/` -- negative fixtures. Each holds a `machine.toml` plus an
  `expect.txt` whose first line is a substring expected in the resolver's
  validation error; the expected outcome is a non-zero exit.
- `_warn-*/` -- warning fixtures. Same `machine.toml` + `expect.txt` shape, but
  the resolver succeeds (exit 0) while emitting the expected warning.

`shared/` holds the shared bundle TOMLs (`dotfiles.toml`, `extbundle.toml`,
`util.toml`) that the fixtures reference.

Run from the repo root:

    task test:manifest
