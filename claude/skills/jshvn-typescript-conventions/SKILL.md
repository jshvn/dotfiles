---
name: jshvn-typescript-conventions
description: Use when working on a TypeScript project - creating or changing biome.json or tsconfig.json, wiring npm scripts, or checking an existing TS repo against the conventions. Carries the shared config core, the operator-surface split, and the converged end state.
---

# TypeScript Conventions

Biome for both lint and format, `strict` on, and the Taskfile as the operator surface
over npm scripts that stay thin.

## End state

A converged repo:

- Formats and lints with Biome, `$schema` pinned to an exact version
- Runs `tsc --noEmit` for types; the bundler emits, TypeScript only checks
- Tests with vitest, exposed as `test: vitest run`
- Keeps npm scripts as one-line primitives and wraps them in a `Taskfile.yml` that
  groups and annotates -- see `jshvn-taskfile-conventions`
- Has one aggregate task running exactly what CI runs

## Biome

The settled core, identical across repos:

    {
      "$schema": "https://biomejs.dev/schemas/2.5.11/schema.json",
      "formatter": { "indentStyle": "space", "indentWidth": 2, "lineWidth": 100 },
      "javascript": { "formatter": { "quoteStyle": "double" } },
      "files": { "includes": ["src/**", "test/**", "biome.json", "package.json"] }
    }

Pin `$schema` to the exact Biome version rather than a floating one -- a schema drifting
under the config is the same class of problem as an unpinned base image.

Scope `files.includes` explicitly. An allowlist of source directories is the safer default;
a `"**"` plus `!` denylist works but needs a new exclusion every time a tool adds a cache
directory (`.next`, `.open-next`, `.wrangler`, `.vercel`).

Two settings are genuinely open and differ across existing repos -- decide per repo rather
than assuming:

- `semicolons`: `"asNeeded"` or `"always"`
- `linter.rules`: `"recommended": true` is the default worth holding. A repo with
  `"preset": "none"` has the linter switched off entirely, which reads as drift rather
  than a decision -- flag it rather than copying it.

## tsconfig

Shared across every repo, and the part worth carrying into a new one:

    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "isolatedModules": true,
    "moduleResolution": "bundler",
    "module": "esnext"

Beyond `strict`, two more are worth switching on wherever a framework does not object:

- `noUncheckedIndexedAccess` -- indexing an array yields `T | undefined`, which is the
  truth and catches the whole class of off-by-one reads
- `verbatimModuleSyntax` -- import elision stops being guesswork

`target` and `lib` follow the framework, not preference: a Next.js app is pinned by Next,
a Worker by the runtime. Do not homogenize those across repos.

## The operator surface

npm scripts stay thin, one command each, no chaining beyond what the tool needs:

    "typecheck": "wrangler types && tsc --noEmit",
    "format":    "biome check .",
    "format:fix": "biome check --write .",
    "test":      "vitest run"

The Taskfile wraps them, and that is where the grouping and the annotations live. The
split matters: npm scripts are the primitives other tools invoke, the Taskfile is what a
person reads. A repo with only npm scripts has no operator surface -- someone returning
after six months gets an unordered JSON object with no indication of which entries are
safe to run.

One aggregate task runs exactly what CI runs -- `task check` covering types, format,
tests, and a dry-run deploy -- so a green local check means a green pipeline.

## Auditing an existing repo

Walk the end-state list. The drift that actually shows up:

- Biome present but `linter` disabled, so only formatting is enforced
- npm scripts with no Taskfile over them
- `$schema` on a version the installed Biome no longer matches
