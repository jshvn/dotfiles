---
status: resolved
trigger: "task manifest:resolve fails with 'Task does not exist'; task list shows manifest:manifest:resolve (double-prefixed). Asymmetry: identity:install / identity:validate appear single-prefixed."
created: 2026-05-15T06:07:38Z
updated: 2026-05-19T05:46:00Z
resolution: "Resolved at v2.1 milestone close. Phase 12 (Task Surface Redesign) renamed the affected manifest tasks; the diagnosis served its purpose but no separate fix was landed. Closing without further action."
---

## Current Focus

hypothesis: CONFIRMED. Root cause is a self-prefixing nomenclature mismatch in `taskfiles/manifest.yml`: every task in that taskfile is declared with the literal key `manifest:resolve`, `manifest:show`, `manifest:validate`, `manifest:test`, `manifest:test:add-machine` (the `manifest:` segment is part of the task key, not just a docstring). When the root `Taskfile.yml` includes the file under the include alias `manifest:`, go-task automatically prepends that include alias to every task name in the included file. The result: `manifest:` (include alias) + `manifest:resolve` (declared key) = the actual fully-qualified task name `manifest:manifest:resolve`. There is NO bug in go-task; the ambiguity was self-introduced and is acknowledged by an inline comment at root `Taskfile.yml:126-128` noting "Refining P1's nomenclature is out of P2 scope". `taskfiles/identity.yml` does NOT exhibit the bug because its tasks are declared with bare keys (`install`, `git`, `ssh`, `validate`, etc.), so the include-alias prefix produces the correct single-prefixed names (`identity:install`, `identity:git`, ...).

test: completed
expecting: completed — see Evidence below
next_action: return ROOT CAUSE FOUND structured result; do NOT fix (diagnose-only mode)

## Symptoms

expected: `task manifest:resolve` resolves the active manifest TOML to JSON cache (per CLAUDE.md quick-reference and PROJECT docs)
actual: `task manifest:resolve` exits with `task: Task "manifest:resolve" does not exist`. Task list shows actual names as `manifest:manifest:resolve`, `manifest:manifest:show`, `manifest:manifest:test`, `manifest:manifest:validate` (double-prefixed). Comparable tasks `identity:install` and `identity:validate` appear single-prefixed (correct).
errors: |
  task: Task "manifest:resolve" does not exist
reproduction: From repo root, run `task manifest:resolve` (fails); run `task --list | grep manifest` (shows double-prefix).
started: Discovered during Phase 04 verify-work UAT on 2026-05-14 (Test 1 in .planning/phases/04-identity-layer-git-ssh-per-machine/04-UAT.md)

## Eliminated

(none — root cause confirmed on first hypothesis from direct code reading)

## Evidence

- timestamp: 2026-05-15T06:08:00Z
  checked: Root `Taskfile.yml` includes block (lines 74-97)
  found: |
    Line 78-83 declares the manifest include with alias key `manifest`:
        manifest:
          taskfile: ./taskfiles/manifest.yml
          vars:
            DOTFILEDIR: '{{.DOTFILEDIR}}'
            XDG_STATE_HOME: '{{.XDG_STATE_HOME}}'
            DOTFILES_MESSAGES: '{{.DOTFILES_MESSAGES}}'
    Line 89-94 declares the identity include with alias key `identity` (same shape).
  implication: |
    Both includes use single-segment alias keys (`manifest`, `identity`). go-task
    will prefix tasks from each included file with that alias + ":". So the
    expected fully-qualified names are `manifest:<key>` and `identity:<key>`.

- timestamp: 2026-05-15T06:08:05Z
  checked: `taskfiles/manifest.yml` task declarations
  found: |
    Line 148: `  manifest:resolve:`        (key declared with embedded "manifest:" prefix)
    Line 174: `  manifest:show:`           (same)
    Line 222: `  manifest:validate:`       (same)
    Line 277: `  manifest:test:`           (same)
    Line 469: `  manifest:test:add-machine:` (same)
  implication: |
    Every public task key in this file already starts with `manifest:`. When
    combined with the root include alias `manifest:`, go-task produces
    `manifest:manifest:resolve`, `manifest:manifest:show`, etc. -- exactly
    matching the observed `task --list` output.

- timestamp: 2026-05-15T06:08:10Z
  checked: `taskfiles/identity.yml` task declarations (control case for asymmetry)
  found: |
    Line 109: `  install:`           (bare key, no embedded prefix)
    Line 121: `  git:`               (bare)
    Line 171: `  server-include:`    (bare)
    Line 212: `  ssh:`               (bare)
    Line 279: `  validate:`          (bare)
    Line 288: `  validate:symlinks:` (bare; the inner `:` is a sub-task convention, not a prefix)
    Line 302: `  validate:git:`      (bare)
    Line 363: `  validate:ssh-add:`  (bare)
    Line 409: `  validate:keys:`     (bare)
  implication: |
    identity.yml task keys do NOT begin with `identity:`. With the root include
    alias `identity:`, go-task produces the correct single-prefixed names
    `identity:install`, `identity:git`, `identity:ssh`, `identity:validate`,
    `identity:validate:symlinks`, etc. This confirms the asymmetry source: only
    manifest.yml self-prefixes its keys.

- timestamp: 2026-05-15T06:08:12Z
  checked: Root `Taskfile.yml:126-128` (inline comment in `install:` task)
  found: |
    # P1 manifest.yml uses redundant `manifest:` prefix on its task names;
    # combined with the `includes: manifest:` here that doubles to
    # `manifest:manifest:resolve`. Refining P1's nomenclature is out of P2 scope.
    deps: [manifest:manifest:resolve]
  implication: |
    The double-prefixing is acknowledged in the codebase as a known nomenclature
    issue from Phase 1 that was deferred. The root install task already works
    around it by depending on the actual fully-qualified `manifest:manifest:resolve`.
    But user-facing docs (CLAUDE.md "Quick Reference") still document the
    intended-but-not-actual names (`task manifest:resolve`, `task manifest:show`),
    creating the truth gap reported in UAT Test 1.

- timestamp: 2026-05-15T06:08:14Z
  checked: `taskfiles/identity.yml:111` (cross-namespace dependency)
  found: |
        install:
          desc: "Install identity layer (git + ssh)"
          deps: [manifest:manifest:resolve]
  implication: |
    identity:install hard-codes a dep on the doubled name `manifest:manifest:resolve`.
    Per UAT Test 5 ("Empty-MANIFEST Guard Fires"), invoking
    `task identity:install` produces:
      task: Task "identity:manifest:manifest:resolve" does not exist  (exit 201)
    Reason: when go-task resolves a `deps:` reference from inside an included
    namespace, names that do not start with a colon are treated as RELATIVE to
    the current include namespace. So `manifest:manifest:resolve` referenced
    from within the `identity:` namespace becomes `identity:manifest:manifest:resolve`,
    which does not exist (the actual task lives at top-level
    `manifest:manifest:resolve`, not under `identity:`). To reference a task in
    another included namespace from inside an include, the dep must be written
    with a leading `:` (e.g., `:manifest:manifest:resolve`) per go-task semantics,
    OR the namespacing must be cleaned up so the task is discoverable by its
    canonical name. This is the same root cause manifesting at a third site:
    docs (gap 1), root install dep (works only by accident-of-documentation),
    and identity:install dep (broken outright, NOT a separate bug).

- timestamp: 2026-05-15T06:08:18Z
  checked: All taskfile references to `manifest:resolve` / `manifest:*` (grep)
  found: |
    taskfiles/manifest.yml:140:      - task: manifest:validate   (intra-file dep, double-prefix in actual key)
    taskfiles/manifest.yml:142:      - task: manifest:resolve    (intra-file dep, double-prefix in actual key)
    taskfiles/manifest.yml:148:  manifest:resolve:               (declaration)
    taskfiles/manifest.yml:174:  manifest:show:                  (declaration)
    taskfiles/manifest.yml:222:  manifest:validate:              (declaration)
    taskfiles/manifest.yml:277:  manifest:test:                  (declaration)
    taskfiles/manifest.yml:469:  manifest:test:add-machine:      (declaration)
    Taskfile.yml:129:    deps: [manifest:manifest:resolve]       (works -- correctly references doubled name)
    taskfiles/identity.yml:111:    deps: [manifest:manifest:resolve]  (broken -- relative resolution prepends "identity:")
    taskfiles/README.md:19-20: documents the names as `manifest:resolve` etc. (matches CLAUDE.md gap)
  implication: |
    The intra-file dep references in manifest.yml lines 140 and 142 work because
    they are resolved relative to manifest.yml itself BEFORE the include alias
    is prepended -- so `manifest:resolve` from within manifest.yml resolves to
    the local task key `manifest:resolve`, which after include-prefixing
    becomes the externally visible `manifest:manifest:resolve`. So self-references
    happen to work even with the broken naming, which is why this issue was
    not caught by the manifest taskfile's own internal tests.

- timestamp: 2026-05-15T06:08:22Z
  checked: go-task version on this machine
  found: 3.50.0  (well above the project minimum of 3.37 -- not a tooling-version issue)
  implication: Confirms this is a nomenclature bug, not a go-task behavior change.

## Resolution

root_cause: |
  `taskfiles/manifest.yml` declares all of its public task keys with a literal
  `manifest:` prefix embedded in the key name (`manifest:resolve`, `manifest:show`,
  `manifest:validate`, `manifest:test`, `manifest:test:add-machine`). When the
  root `Taskfile.yml` includes that file under the alias `manifest`, go-task
  prepends the alias to every included task name, producing the doubled
  fully-qualified names `manifest:manifest:resolve`, `manifest:manifest:show`, etc.
  All other included taskfiles (notably `taskfiles/identity.yml`) declare their
  tasks with bare keys (`install`, `git`, `ssh`, `validate`), so the alias
  prefix produces the canonical single-prefixed names. The bug is acknowledged
  in an inline comment at root `Taskfile.yml:126-128` as a Phase 1 nomenclature
  artifact deferred out of Phase 2 scope; it never got cleaned up. The
  user-facing docs in CLAUDE.md and `taskfiles/README.md` document the intended
  (clean) names, creating a documentation/code truth gap.

  The bug additionally cascades into Phase 4: `taskfiles/identity.yml:111`
  declares `deps: [manifest:manifest:resolve]`, but go-task resolves
  unqualified deps RELATIVE to the current include namespace, so from inside
  `identity:` this becomes `identity:manifest:manifest:resolve` -- a
  triple-prefixed name that does not exist. Net effect: `task identity:install`
  is unrunnable (exit 201, "Task does not exist"), and by extension the
  canonical `task install` pipeline cannot complete end-to-end either if/when
  it transitively tries to invoke identity tasks from within a namespace
  context. Same single root cause; three observable failure sites
  (docs vs reality, identity:install cascade, transitive install cascade).

fix: (not applied — diagnose-only mode)
verification: (n/a — diagnose-only)
files_changed: []
