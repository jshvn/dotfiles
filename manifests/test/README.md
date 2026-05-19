# manifests/test

Golden-output test fixtures for the deep-merge resolver (`install/resolver.zsh`).

Each positive fixture under `fixtures/0N-*/` contains three files: `defaults.toml`,
`machine.toml`, and `expected.json`. The driver merges the two TOMLs and diffs the
result against `expected.json`. Negative fixtures (`fixtures/_invalid-*/`) hold only
`machine.toml`; their expected outcome is a non-zero exit from validation.

Run from the repo root:

    task manifest:test

Phase-1 invocation before the root Taskfile wires this in:
`task -t taskfiles/manifest.yml manifest:test`.
