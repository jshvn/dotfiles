# Manifest Tier Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a machine manifest the complete, readable answer to "what did I
choose to install here?" by splitting packages into three tiers -- unconditional
base, feature-owned, and discretionary -- and deleting `manifests/bundles/`.

**Architecture:** Two phases. Phase A is purely additive: `manifests/base.toml`
and `[<flag>.packages]` tables are introduced alongside the existing bundles, and
because the union dedupes, `resolved.json` is provably byte-identical for all
four machines. Phase B cuts over: machine manifests inline their discretionary
packages, the bundle machinery leaves the resolver, `schema_version` goes to 3,
and `manifests/bundles/` is deleted -- changing `resolved.json` by exactly seven
entries on atium and one on ci.

**Tech Stack:** zsh, go-task >= 3.37, yq (mikefarah) >= 4.52.1, jq >= 1.7,
Homebrew. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-02-manifest-tier-restructure-design.md`

## Global Constraints

- Commit format: `<type>(<scope>): <summary>` (<75 chars, imperative mood).
  No AI attribution anywhere (hooks block it).
- No emojis in any file, including markdown.
- Every executable `.zsh` starts with `set -euo pipefail` (LINT-04) and the
  Purpose / Depends on / Side effects banner between two `# ===` 77-char rules
  (LINT-12).
- Multi-element TOML arrays span one element per line; empty and
  single-element inline arrays are exempt (LINT-13).
- `status:` blocks use `{{.X}}` template vars, never `$X` shell vars (LINT-02).
- Kebab-case feature keys use the `index` template form, never dot-access
  (LINT-11).
- Errors go to stderr via `error "..."` from `install/messages.zsh`.
- Comments describe the current system only -- never reference bundles as a
  replaced system, never narrate the migration. That story lives in commit
  messages.
- Branch per phase: `josh/manifest-tiers-phase-a`, `josh/manifest-tiers-phase-b`.
  PR to master, squash merge.
- After every task: `task lint` and `task test` both pass before commit.
- `install/resolver.zsh` must stay under the 800-line file cap (it is 672 now
  and this plan removes more than it adds).

## Interaction with the existing NixOS plan

`docs/superpowers/plans/2026-07-23-nixos-architecture-improvements.md` Task 8
(Phase 4, "Registry packages tables folded in by the resolver") is a strict
subset of this plan and is deleted by Task 7 below. Its Phases 1-3 are
untouched.

This plan operates at the **current** test paths (`manifests/test/`,
`taskfiles/test/`). If that plan's Phase 1 rename lands later, its
`git mv manifests/test manifests/tests` still applies cleanly -- this plan only
changes files *inside* those directories, never the directory names.

## File Structure

**Created:**
- `manifests/base.toml` -- unconditional package tier; 22 formulae, no casks.
- `manifests/test/shared/base.toml` -- fixture-scope base tier (replaces the
  four test bundle files).
- `manifests/test/fixtures/typed-05-feature-packages/` -- proves enabled flags
  contribute packages and disabled flags do not.
- `manifests/test/fixtures/_invalid-registry-packages-shape/` -- rejects a
  malformed `[<flag>.packages]` bucket.
- `manifests/test/fixtures/_invalid-redundant-package/` -- rejects a machine
  listing a package base already provides.

**Modified:**
- `install/resolver.zsh` -- gains `BASE_TOML`, `--base`, `feature_bucket`,
  registry-packages shape validation, and the redundancy rule; loses
  `bundle_files_for`, `SHARED_DIR`, `--shared-dir`, the `packages.bundles`
  validation block, and the `bundles` output field.
- `manifests/features.toml` -- `[<flag>.packages]` on five flags; two new flags.
- `manifests/machines/{personal-laptop,work-laptop,atium,ci}.toml` -- schema 3,
  new flag accounting, discretionary packages inlined, `bundles` key removed.
- `taskfiles/test.yml` -- `--shared-dir` becomes `--base`.
- `manifests/test/fixtures/typed-0{1,2,3,4}-*/` -- rewritten onto base + flags.
- `docs/MANIFEST.md`, `CLAUDE.md`, `manifests/README.md`,
  `manifests/machines/README.md`, `manifests/test/README.md`,
  `docs/NIXOS-ARCHITECTURE-LEARNINGS.md`.

**Deleted:**
- `manifests/bundles/` (all 6 TOML files + README.md).
- `manifests/test/shared/{dotfiles,util,extras,extbundle}.toml`.

---

# Phase A -- additive foundation (branch `josh/manifest-tiers-phase-a`)

**Phase invariant:** at the end of every task in this phase,
`task manifest:show -- --machine N` is byte-identical to the Task 1 baseline for
all four machines. Any diff is a bug.

## Task 1: Baseline snapshot, base.toml, and the base tier fold-in

**Files:**
- Create: `/tmp/manifest-baseline/{personal-laptop,work-laptop,atium,ci}.json`
  (throwaway verification artifact, not committed)
- Create: `manifests/base.toml`
- Create: `manifests/test/fixtures/typed-06-base-tier/{machine.toml,features.toml,expected.json}`
- Create: `manifests/test/shared/base.toml`
- Modify: `install/resolver.zsh`
- Modify: `taskfiles/test.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: the global `BASE_TOML` (default
  `${DOTFILEDIR}/manifests/base.toml`, overridable by the test-only `--base
  <path>` flag); `union_bucket <machine_file> <key> <finalize_jq>
  <feature_json> <bundle_file...>` (new 4th positional arg, folds `BASE_TOML`
  first). Tasks 2-8 all rely on both.

- [ ] **Step 1: Capture the baseline**

```bash
cd /Users/josh/Git/personal/dotfiles
mkdir -p /tmp/manifest-baseline
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout \
    | jq -S . > "/tmp/manifest-baseline/${m}.json"
done
wc -l /tmp/manifest-baseline/*.json
```

Expected: four non-empty files. These are the Phase A gate; do not regenerate
them after this step.

- [ ] **Step 2: Write the failing fixture**

Create `manifests/test/shared/base.toml`:

```toml
# Test-scope base tier for typed-bucket fixtures only. NEVER referenced by real
# machine manifests -- selection happens via the resolver's --base flag in the
# test runner. Keep contents stable: every typed-* fixture's expected.json locks
# in the resolved output, so changing a package here cascades to all of them.

[packages]
formulae = [
  "curl",
  "git",
]
```

Create `manifests/test/fixtures/typed-06-base-tier/machine.toml`:

```toml
# typed-06-base-tier -- the base tier folds into every machine with no machine
# declaring it. The test base.toml declares curl + git; the machine declares
# ripgrep and no bundles. Expected: [curl, git, ripgrep].

schema_version = 2

[machine]
description = "typed-06-base-tier fixture"
os = "darwin"
identity = "none"

[features]
enabled = []
disabled = []

[packages]
bundles = [
  "dotfiles",
]
formulae = [
  "ripgrep",
]
```

Create `manifests/test/fixtures/typed-06-base-tier/features.toml`:

```toml
# Empty feature registry for package-only fixtures (no flags to account).
```

Create `manifests/test/fixtures/typed-06-base-tier/expected.json`:

```json
{
  "meta": {
    "description": "typed-06-base-tier fixture"
  },
  "platform": {
    "os": "darwin",
    "arch": "FROM_UNAME"
  },
  "features": {},
  "identity": {
    "git": "none",
    "ssh": "none"
  },
  "packages": {
    "brew": {
      "bundles": [
        "dotfiles"
      ],
      "formulae": [
        "curl",
        "git",
        "ripgrep"
      ],
      "casks": [],
      "mas": []
    },
    "vscode": {
      "extensions": []
    },
    "cargo": {
      "crates": []
    },
    "uv": {
      "tools": []
    },
    "npm": {
      "packages": []
    }
  },
  "claude": {
    "addons": []
  }
}
```

Note this fixture still declares `bundles = ["dotfiles"]` because
`packages.bundles` is still required in Phase A; the test bundle
`manifests/test/shared/dotfiles.toml` also declares curl + git, so the union is
identical either way. Task 5 removes the bundle line.

- [ ] **Step 3: Run it to verify it fails**

```bash
task test 2>&1 | grep typed-06
```

Expected: FAIL -- the resolver does not know about `--base` yet, so the runner's
invocation errors out with `unknown argument: --base` (added in Step 5).

- [ ] **Step 4: Add BASE_TOML and fold it into union_bucket**

In `install/resolver.zsh`, after the `SHARED_DIR` declaration (line 27), add:

```zsh
# BASE_TOML is overridable via the --base CLI flag (testing only -- see main()
# arg parser). Holds the unconditional package tier: every machine running these
# dotfiles receives it and no machine declares it.
typeset BASE_TOML="${DOTFILEDIR}/manifests/base.toml"
```

Replace the `union_bucket` function (lines 412-427) with:

```zsh
# union_bucket <machine_file> <key> <finalize_jq> <feature_json> <bundle_file...>
# Concatenate the .packages.<key> arrays from the base tier, then each bundle
# (declared order), then the enabled-feature packages, then the machine, and
# apply the finalize jq expression. Bare-string buckets use `add | unique`;
# casks wrap to { name } objects; mas dedupes by .id (last wins, so the machine
# overrides base, a bundle, or a feature).
union_bucket() {
  local machine_file="$1" key="$2" finalize="$3" feature_json="$4"
  shift 4
  {
    yq -o=json ".packages.${key} // []" "$BASE_TOML"
    local f
    for f in "$@"; do
      yq -o=json ".packages.${key} // []" "$f"
    done
    printf '%s\n' "${feature_json:-[]}"
    yq -o=json ".packages.${key} // []" "$machine_file"
  } | jq -s "$finalize"
}
```

In `resolve_pipeline`, update the seven call sites (lines 459-465) to pass an
empty feature bucket for now -- Task 2 replaces `'[]'` with `feature_bucket`
calls:

```zsh
  union_formulae=$(union_bucket "$machine_file" formulae 'add | unique' '[]' "${bundle_files[@]}")
  union_casks=$(union_bucket    "$machine_file" casks    'add | unique | map({ name: . })' '[]' "${bundle_files[@]}")
  union_mas=$(union_bucket      "$machine_file" mas      'add | group_by(.id) | map(.[-1])' '[]' "${bundle_files[@]}")
  union_vscode=$(union_bucket   "$machine_file" vscode   'add | unique' '[]' "${bundle_files[@]}")
  union_cargo=$(union_bucket    "$machine_file" cargo    'add | unique' '[]' "${bundle_files[@]}")
  union_uv=$(union_bucket       "$machine_file" uv       'add | unique' '[]' "${bundle_files[@]}")
  union_npm=$(union_bucket      "$machine_file" npm      'add | unique' '[]' "${bundle_files[@]}")
```

In `validate_manifest`, immediately after the registry-existence check block
(the `if [[ ! -f "$REGISTRY" ]]` ... closing `fi` at line 279), add:

```zsh
  # Base tier must exist -- every machine's package set is built on top of it.
  if [[ ! -f "$BASE_TOML" ]]; then
    error "base manifest not found: ${BASE_TOML}"
    errors=$(( errors + 1 ))
  fi
```

Update the file-header banner: the `Purpose:` line's "and the bundle set
(manifests/bundles/)" becomes "the bundle set (manifests/bundles/), and the base
tier (manifests/base.toml)".

- [ ] **Step 5: Add the --base CLI flag**

In `main()`'s arg parser, after the `--shared-dir` case (line 584), add:

```zsh
      --base)
        # Testing only: override path to base.toml.
        if (( $# < 2 )); then error "--base requires an argument"; return 1; fi
        BASE_TOML="$2"; shift 2 ;;
```

In the `--help` heredoc, add under the test-only flags block:

```
  --base <path>           override manifests/base.toml path
```

- [ ] **Step 6: Point the fixture runner at the test base**

In `taskfiles/test.yml`, after the `test_shared_dir=` line (line 96), add:

```
        test_base="{{.ROOT_DIR}}/manifests/test/shared/base.toml"
```

In the typed-fixture resolver invocation (line 171), add the flag:

```
            --shared-dir "$test_shared_dir" \
            --base "$test_base" 2>/dev/null) || {
```

Negative fixtures run `--validate-only`, which now also checks base existence.
Add `--base "$test_base"` to the `_run_negative_fixture` invocation (line 134)
so negative fixtures do not fail on a missing production base:

```
            --validate-only --machine "$sandboxed_name" --registry "$reg" \
            --base "$test_base" 2>&1 >/dev/null || true)
```

- [ ] **Step 7: Create the production base tier**

Create `manifests/base.toml`:

```toml
# manifests/base.toml -- the unconditional package tier.
#
# Every machine running these dotfiles receives these packages. No machine
# manifest declares them, and listing one in a machine's [packages] is a hard
# error (the resolver's redundancy rule). Two kinds of thing live here:
#
#   - Bootstrap toolchain: the resolver and task system cannot run without it
#     (zsh, git, coreutils, grep, openssh, yq, jq, go-task, mas).
#   - Shell-config dependencies: aliases, functions, and configs under shell/
#     and configs/ break without them.
#
# A package needed only by a specific feature belongs on that feature's flag in
# manifests/features.toml, not here. A package you simply want on a machine
# belongs in that machine's [packages].
#
# Schema reference: docs/MANIFEST.md.
#
# Notes:
#   - "antidote" is the zsh plugin manager; see shell/.zshrc and
#     shell/.zsh_plugins.txt for usage.
#   - "libpsl" provides the `psl` CLI used by shell/functions/whois.zsh to
#     reduce a host to its registrable domain (eTLD+1) via the Public Suffix
#     List; without it whois() falls back to querying the host unreduced.
#   - "mas" is the Mac App Store CLI that installs every [packages] mas entry.

[packages]
formulae = [
  "antidote",
  "cloudflared",
  "coreutils",
  "eza",
  "fastfetch",
  "git",
  "git-delta",
  "go-task",
  "grc",
  "grep",
  "highlight",
  "jq",
  "libpsl",
  "mas",
  "ncdu",
  "onefetch",
  "openssh",
  "tlrc",
  "trippy",
  "whois",
  "yq",
  "zsh",
]
```

- [ ] **Step 8: Run the fixture to verify it passes**

```bash
task test 2>&1 | grep -E 'typed-06|fixtures:'
```

Expected: `typed-06-base-tier -- pass`, and the fixtures summary reports zero
failures.

- [ ] **Step 9: Verify the phase invariant**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout \
    | jq -S . > "/tmp/manifest-after-t1-${m}.json"
  if diff -q "/tmp/manifest-baseline/${m}.json" "/tmp/manifest-after-t1-${m}.json" >/dev/null; then
    echo "OK   $m unchanged"
  else
    echo "FAIL $m changed"; diff "/tmp/manifest-baseline/${m}.json" "/tmp/manifest-after-t1-${m}.json"
  fi
done
```

Expected: four `OK` lines. `base.toml` duplicates packages that
`bundles/dotfiles.toml` already provides, and the union dedupes, so nothing moves.

- [ ] **Step 10: Full verification and commit**

```bash
task lint && task test
```

Expected: both pass.

```bash
git add -A
git commit -m "feat(manifests): add unconditional base package tier"
```

## Task 2: Registry packages tables folded in by the resolver

**Files:**
- Create: `manifests/test/fixtures/typed-05-feature-packages/{machine.toml,features.toml,expected.json}`
- Create: `manifests/test/fixtures/_invalid-registry-packages-shape/{machine.toml,features.toml,expect.txt}`
- Modify: `install/resolver.zsh`

**Interfaces:**
- Consumes: `BASE_TOML` and the 4-arg `union_bucket` from Task 1.
- Produces: `feature_bucket <key>` (defined inside `resolve_pipeline`; returns
  the union of `packages.<key>` across enabled flags as a JSON array) and the
  registry schema extension `[<flag>.packages]` with the seven bucket keys.
  Task 3 populates those tables; Task 4's redundancy rule reads them.

- [ ] **Step 1: Write the failing positive fixture**

Create `manifests/test/fixtures/typed-05-feature-packages/features.toml`:

```toml
# Registry for typed-05: one enabled flag carrying packages, one disabled flag
# whose packages must not appear in the resolved set.

[flag-with-packages]
description = "test flag carrying packages"

[flag-with-packages.packages]
formulae = ["feat-formula"]
casks = ["feat-cask"]

[flag-disabled-packages]
description = "disabled flag whose packages must not appear"

[flag-disabled-packages.packages]
formulae = ["absent-formula"]
```

Create `manifests/test/fixtures/typed-05-feature-packages/machine.toml`:

```toml
# typed-05-feature-packages -- an ENABLED registry flag's [<flag>.packages]
# buckets fold into the resolved set; a DISABLED flag's contribute nothing.
# absent-formula must not appear anywhere in the output.

schema_version = 2

[machine]
description = "typed-05-feature-packages fixture"
os = "darwin"
identity = "none"

[features]
enabled = [
  "flag-with-packages",
]
disabled = [
  "flag-disabled-packages",
]

[packages]
bundles = [
  "dotfiles",
]
```

Create `manifests/test/fixtures/typed-05-feature-packages/expected.json`:

```json
{
  "meta": {
    "description": "typed-05-feature-packages fixture"
  },
  "platform": {
    "os": "darwin",
    "arch": "FROM_UNAME"
  },
  "features": {
    "flag-with-packages": true,
    "flag-disabled-packages": false
  },
  "identity": {
    "git": "none",
    "ssh": "none"
  },
  "packages": {
    "brew": {
      "bundles": [
        "dotfiles"
      ],
      "formulae": [
        "curl",
        "feat-formula",
        "git"
      ],
      "casks": [
        {
          "name": "feat-cask"
        }
      ],
      "mas": []
    },
    "vscode": {
      "extensions": []
    },
    "cargo": {
      "crates": []
    },
    "uv": {
      "tools": []
    },
    "npm": {
      "packages": []
    }
  },
  "claude": {
    "addons": []
  }
}
```

- [ ] **Step 2: Write the failing negative fixture**

Create `manifests/test/fixtures/_invalid-registry-packages-shape/features.toml`:

```toml
# negative fixture registry -- a flag whose packages table names a bucket that
# does not exist.

[bad-flag]
description = "flag with a bad packages bucket"

[bad-flag.packages]
notabucket = ["x"]
```

Create `manifests/test/fixtures/_invalid-registry-packages-shape/machine.toml`:

```toml
# negative fixture -- a registry flag declaring an unknown packages bucket must
# be rejected.

schema_version = 2

[machine]
description = "registry-packages-shape fixture"
os = "darwin"
identity = "none"

[features]
enabled = []
disabled = [
  "bad-flag",
]

[packages]
bundles = [
  "dotfiles",
]
```

Create `manifests/test/fixtures/_invalid-registry-packages-shape/expect.txt`:

```
unknown packages bucket
registry flag declares an unknown packages bucket
```

- [ ] **Step 3: Run to verify both fail**

```bash
task test 2>&1 | grep -E 'typed-05|registry-packages-shape'
```

Expected: `typed-05-feature-packages -- FAIL` (diff shows `feat-formula` and
`feat-cask` missing from actual) and `_invalid-registry-packages-shape --
expected rejection` (the resolver currently accepts the malformed table).

- [ ] **Step 4: Add registry packages shape validation**

In `install/resolver.zsh`'s `validate_manifest`, inside the `else` branch that
already computed `registry_json`, immediately after the
`if [[ -n "$accounting" ]] ... fi` block (line 278) and still inside that
`else`, add:

```zsh
    # Registry packages shape: a flag's optional [<flag>.packages] table may
    # only declare the seven bucket keys; bare-string arrays except mas
    # ({ id, name } objects). One line per violation.
    local reg_pkg_bad
    reg_pkg_bad=$(jq -rn --argjson reg "$registry_json" '
      $reg | to_entries
      | map(select((.value | type) == "object" and (.value | has("packages"))))
      | map(.key as $flag | (.value.packages | to_entries | map(
          if (["formulae","casks","mas","vscode","cargo","uv","npm"] | index(.key)) == null
          then "registry flag \($flag): unknown packages bucket \(.key)"
          elif .key == "mas"
          then (if (.value | map(select((.id | type) != "number" or (.name | type) != "string")) | length) > 0
                then "registry flag \($flag): packages.mas entries must be { id, name } objects" else empty end)
          else (if (.value | map(select(type != "string")) | length) > 0
                then "registry flag \($flag): packages.\(.key) entries must be bare strings" else empty end)
          end)))
      | flatten | .[]' 2>/dev/null || true)
    if [[ -n "$reg_pkg_bad" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        error "$line"
        errors=$(( errors + 1 ))
      done <<< "$reg_pkg_bad"
    fi
```

- [ ] **Step 5: Add feature_bucket and wire the call sites**

In `resolve_pipeline`, after the `features_map=$(...)` assignment (line 449),
add:

```zsh
  # Feature-declared packages: an enabled registry flag's optional
  # [<flag>.packages] buckets fold into the same union as base + machine.
  local registry_json
  registry_json=$(yq -o=json '.' "$REGISTRY" 2>/dev/null || echo '{}')
  [[ -z "$registry_json" || "$registry_json" == "null" ]] && registry_json='{}'

  # feature_bucket <key>: union of packages.<key> arrays declared by every
  # ENABLED flag. Disabled flags contribute nothing.
  feature_bucket() {
    local key="$1"
    jq -n --argjson reg "$registry_json" --argjson en "$enabled_json" --arg key "$key" \
      '[$en[] as $f | ($reg[$f].packages[$key] // [])] | add // []'
  }
```

Replace the seven `'[]'` placeholders from Task 1 Step 4 with real calls:

```zsh
  union_formulae=$(union_bucket "$machine_file" formulae 'add | unique' "$(feature_bucket formulae)" "${bundle_files[@]}")
  union_casks=$(union_bucket    "$machine_file" casks    'add | unique | map({ name: . })' "$(feature_bucket casks)" "${bundle_files[@]}")
  union_mas=$(union_bucket      "$machine_file" mas      'add | group_by(.id) | map(.[-1])' "$(feature_bucket mas)" "${bundle_files[@]}")
  union_vscode=$(union_bucket   "$machine_file" vscode   'add | unique' "$(feature_bucket vscode)" "${bundle_files[@]}")
  union_cargo=$(union_bucket    "$machine_file" cargo    'add | unique' "$(feature_bucket cargo)" "${bundle_files[@]}")
  union_uv=$(union_bucket       "$machine_file" uv       'add | unique' "$(feature_bucket uv)" "${bundle_files[@]}")
  union_npm=$(union_bucket      "$machine_file" npm      'add | unique' "$(feature_bucket npm)" "${bundle_files[@]}")
```

The existing `PACKAGE_NAME_RE` check runs on the fully-unioned set, so
feature-injected names inherit the Brewfile-injection guard with no extra work.

- [ ] **Step 6: Run fixtures to verify green**

```bash
task test 2>&1 | grep -E 'typed-05|registry-packages-shape|fixtures:'
```

Expected: typed-05 passes, `_invalid-registry-packages-shape` is correctly
rejected, and the summary reports zero failures.

- [ ] **Step 7: Verify the phase invariant**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout | jq -S . \
    | diff -q "/tmp/manifest-baseline/${m}.json" - >/dev/null \
    && echo "OK   $m unchanged" || echo "FAIL $m changed"
done
```

Expected: four `OK` lines. No flag declares packages yet, so `feature_bucket`
returns `[]` everywhere.

- [ ] **Step 8: Full verification and commit**

```bash
task lint && task test
```

```bash
git add -A
git commit -m "feat(manifests): registry flags may declare their packages"
```

## Task 3: Populate the flags and mint the two new ones

**Files:**
- Modify: `manifests/features.toml`
- Modify: `manifests/machines/{personal-laptop,work-laptop,atium,ci}.toml`

**Interfaces:**
- Consumes: `feature_bucket` and the registry shape validation from Task 2.
- Produces: the populated flag vocabulary (`repo-dev-toolchain`, `vscode`,
  `ghostty`, `one-password-ssh`, `one-password-signing` all carrying packages)
  that Phase B's machine rewrite depends on for its package coverage.

- [ ] **Step 1: Add packages to the three existing flags**

In `manifests/features.toml`, extend the header comment block by adding this
paragraph immediately before the `platforms:` paragraph:

```
# packages: a flag may declare an optional [<flag>.packages] table using the
# same bucket shape as manifests/base.toml and a machine's [packages]
# (formulae, casks, mas, vscode, cargo, uv, npm). The resolver unions those
# buckets into the resolved set when a machine enables the flag; a disabled
# flag contributes nothing. A feature's own tooling belongs here, so enabling
# the feature guarantees the tools it needs.
```

Replace the `[one-password-ssh]` and `[one-password-signing]` blocks with:

```toml
[one-password-ssh]
description = "link the 1Password SSH agent config; agent socket exported in .zprofile"
platforms = ["darwin"]

# The agent socket lives inside the 1Password application bundle.
[one-password-ssh.packages]
casks = ["1password"]

[one-password-signing]
description = "git commit signing via the 1Password op-ssh-sign program"
platforms = ["darwin"]

# op-ssh-sign ships inside the 1Password application bundle; see the [gpg]
# program path in identity/git/identities/*. The union dedupes against
# one-password-ssh when both flags are enabled.
[one-password-signing.packages]
casks = ["1password"]
```

Replace the `[ghostty]` block with:

```toml
[ghostty]
description = "gate shell/aliases/ghostty.zsh and the ghostty config link"

[ghostty.packages]
casks = ["ghostty"]
```

- [ ] **Step 2: Mint repo-dev-toolchain**

In `manifests/features.toml`, immediately after the `[repo-auto-update]` block,
add:

```toml
[repo-dev-toolchain]
description = "lint and format tooling required to run task lint on this repo"

# Consumed by taskfiles/lint.yml and install/lint-rules.zsh. A machine that
# only uses these dotfiles (rather than developing them) does not need these.
[repo-dev-toolchain.packages]
formulae = [
  "biome",
  "hyperfine",
  "ruff",
  "shellcheck",
  "shfmt",
  "taplo",
]
```

- [ ] **Step 3: Mint vscode**

In `manifests/features.toml`, immediately after the `[ghostty]` blocks, add:

```toml
[vscode]
description = "install Visual Studio Code and its extension set"

# The cask provides the `code` CLI that the extensions install through, so the
# two must travel together. Extensions are emitted as `vscode '<id>'` Brewfile
# lines.
[vscode.packages]
casks = ["visual-studio-code"]
vscode = [
  "1password.op-vscode",
  "anthropic.claude-code",
  "docker.docker",
  "eamodio.gitlens",
  "esbenp.prettier-vscode",
  "github.vscode-github-actions",
  "mathematic.vscode-pdf",
  "mechatroner.rainbow-csv",
  "ms-azuretools.vscode-containers",
  "ms-azuretools.vscode-docker",
  "ms-kubernetes-tools.vscode-kubernetes-tools",
  "ms-python.debugpy",
  "ms-python.isort",
  "ms-python.python",
  "ms-python.vscode-pylance",
  "ms-python.vscode-python-envs",
  "ms-toolsai.jupyter",
  "ms-toolsai.jupyter-keymap",
  "ms-toolsai.jupyter-renderers",
  "ms-toolsai.vscode-jupyter-cell-tags",
  "ms-toolsai.vscode-jupyter-slideshow",
  "ms-vscode-remote.remote-containers",
  "ms-vscode-remote.remote-ssh",
  "ms-vscode-remote.remote-ssh-edit",
  "ms-vscode.makefile-tools",
  "ms-vscode.remote-explorer",
  "pkief.material-icon-theme",
  "redhat.vscode-yaml",
  "task.vscode-task",
]
```

- [ ] **Step 4: Account for the two new flags on every machine**

Two new registry flags mean every machine must place each in `enabled` or
`disabled` or `task setup` hard-fails. Make exactly these edits.

`manifests/machines/personal-laptop.toml` -- in `features.enabled`, insert
`"repo-dev-toolchain",` after `"repo-auto-update",` and `"vscode",` after
`"ghostty",`.

`manifests/machines/work-laptop.toml` -- same two insertions in
`features.enabled`.

`manifests/machines/atium.toml` -- in `features.disabled`, insert
`"repo-dev-toolchain",` and `"vscode",` (atium neither lints this repo nor runs
a GUI editor).

`manifests/machines/ci.toml` -- insert `"repo-dev-toolchain",` into
`features.enabled` (ci runs `task lint` and `task test`, so it genuinely needs
those six formulae) and `"vscode",` into `features.disabled`.

- [ ] **Step 5: Verify the phase invariant**

Two new registry flags mean the `features` map in `resolved.json` gains two keys
on every machine. That is a real and expected diff. Everything else -- every
package bucket -- must be byte-identical, because each package a flag now
declares is *also* still declared by a bundle the machine takes, so the union
dedupes to the same set.

Check the two halves separately:

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout | jq -S . \
    > "/tmp/manifest-after-t3-${m}.json"
  echo "=== $m ==="
  if diff -q <(jq -S 'del(.features)' "/tmp/manifest-baseline/${m}.json") \
             <(jq -S 'del(.features)' "/tmp/manifest-after-t3-${m}.json") >/dev/null; then
    echo "  packages identical"
  else
    echo "  PACKAGES CHANGED -- stop and diagnose"
    diff <(jq -S 'del(.features)' "/tmp/manifest-baseline/${m}.json") \
         <(jq -S 'del(.features)' "/tmp/manifest-after-t3-${m}.json")
  fi
  echo "  features delta:"
  diff <(jq -S '.features' "/tmp/manifest-baseline/${m}.json") \
       <(jq -S '.features' "/tmp/manifest-after-t3-${m}.json") || true
done
```

Expected: `packages identical` for all four machines, and a features delta of
exactly two added keys per machine matching Step 4 --
`repo-dev-toolchain: true` and `vscode: true` on the laptops,
`repo-dev-toolchain: false, vscode: false` on atium,
`repo-dev-toolchain: true, vscode: false` on ci.

- [ ] **Step 6: Full verification and commit**

```bash
task lint && task test
task manifest:show | jq -r '.features | to_entries[] | select(.key=="repo-dev-toolchain" or .key=="vscode") | "\(.key)=\(.value)"'
```

Expected: `task lint` and `task test` pass; the last command prints
`repo-dev-toolchain=true` and `vscode=true` on this laptop.

```bash
git add -A
git commit -m "feat(features): flags declare the packages their concern needs"
```

---

# Phase B -- cut over (branch `josh/manifest-tiers-phase-b`)

**Phase gate:** after Task 6, `resolved.json` differs from the Task 1 baseline by
exactly seven entries on atium (six lint formulae plus `1password-cli`) and one
on ci (`1password-cli`). personal-laptop and work-laptop are unchanged apart from
the two features keys added in Task 3.

## Task 4: The redundancy rule

**Files:**
- Create: `manifests/test/fixtures/_invalid-redundant-package/{machine.toml,expect.txt}`
- Modify: `install/resolver.zsh`

**Interfaces:**
- Consumes: `BASE_TOML` (Task 1), `registry_json` and `enabled_json` already
  local to `validate_manifest`.
- Produces: the hard error that keeps the three tiers from blurring. Task 6's
  machine rewrite must satisfy it.

- [ ] **Step 1: Write the failing negative fixture**

Create `manifests/test/fixtures/_invalid-redundant-package/machine.toml`:

```toml
# negative fixture -- a machine listing a package the base tier already provides
# must be rejected. The test base (manifests/test/shared/base.toml) declares
# git; re-declaring it here is redundant.

schema_version = 2

[machine]
description = "redundant-package fixture"
os = "darwin"
identity = "none"

[features]
enabled = []
disabled = []

[packages]
bundles = [
  "dotfiles",
]
formulae = [
  "git",
]
```

Create `manifests/test/fixtures/_invalid-redundant-package/expect.txt`:

```
is already provided by
machine re-declares a base or feature package
```

This fixture ships no `features.toml`, so the runner passes the real registry --
which is correct here: the violation is against the base tier, not a flag.

- [ ] **Step 2: Run to verify it fails**

```bash
task test 2>&1 | grep redundant-package
```

Expected: `_invalid-redundant-package -- expected rejection with 'is already
provided by' in stderr` -- the resolver currently accepts the duplicate.

- [ ] **Step 3: Implement the redundancy rule**

In `install/resolver.zsh`'s `validate_manifest`, immediately after the
`packages.*` bucket shape check (the `if [[ -n "$bad_shape" ]] ... fi` block
ending at line 368), add:

```zsh
  # Redundancy: a machine must not list a package that the base tier or an
  # ENABLED feature already provides -- the machine manifest is the record of
  # deliberate choices, and a duplicate blurs that. mas is exempt: a machine mas
  # entry deliberately overrides a base/feature entry with the same id via the
  # last-wins dedupe. Only enabled flags count; listing a package a DISABLED
  # flag would have provided is a legitimate deliberate choice.
  if [[ -f "$BASE_TOML" && -f "$REGISTRY" ]]; then
    local redundant base_pkgs_json machine_pkgs_json reg_json_local
    base_pkgs_json=$(yq -o=json '.packages // {}' "$BASE_TOML" 2>/dev/null || echo '{}')
    machine_pkgs_json=$(yq -o=json '.packages // {}' "$machine_file" 2>/dev/null || echo '{}')
    reg_json_local=$(yq -o=json '.' "$REGISTRY" 2>/dev/null || echo '{}')
    [[ -z "$reg_json_local" || "$reg_json_local" == "null" ]] && reg_json_local='{}'
    redundant=$(jq -rn \
      --argjson base "$base_pkgs_json" \
      --argjson reg "$reg_json_local" \
      --argjson en "$enabled_json" \
      --argjson mach "$machine_pkgs_json" '
      ["formulae","casks","vscode","cargo","uv","npm"] as $buckets
      | [ $buckets[] as $b
          | ( ($base[$b] // []) + [ $en[] as $f | ($reg[$f].packages[$b] // [])[] ] ) as $provided
          | ( ($mach[$b] // []) | map(select(IN($provided[])))
              | .[]
              | "packages.\($b) entry '\(.)' is already provided by the base tier or an enabled feature -- remove it from the machine manifest" ) ]
      | .[]' 2>/dev/null || true)
    if [[ -n "$redundant" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        error "$line"
        errors=$(( errors + 1 ))
      done <<< "$redundant"
    fi
  fi
```

- [ ] **Step 4: Run to verify it passes**

```bash
task test 2>&1 | grep -E 'redundant-package|fixtures:'
```

Expected: `_invalid-redundant-package -- correctly rejected`, summary reports
zero failures.

- [ ] **Step 5: Confirm real machines still validate**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --validate-only --machine "$m" \
    && echo "OK   $m" || echo "FAIL $m"
done
```

Expected: four `OK` lines. Machines still declare bundles rather than inlined
packages at this point, and none of their inline extras appear in base or in an
enabled flag's tables.

- [ ] **Step 6: Full verification and commit**

```bash
task lint && task test
```

```bash
git add -A
git commit -m "feat(resolver): reject machine packages base or a flag provides"
```

## Task 5: Migrate fixtures off bundles

**Files:**
- Modify: `install/resolver.zsh` (relax the three `packages.bundles` requirement rules)
- Modify: `manifests/test/fixtures/typed-0{1,2,3,4,5,6}-*/machine.toml`
- Modify: `manifests/test/fixtures/typed-0{1,2,3,4,5,6}-*/expected.json`
- Modify: `manifests/test/fixtures/typed-0{3,4}-*/features.toml` (new; carry the
  packages the bundles used to)
- Modify: `manifests/test/fixtures/_invalid-*/machine.toml` (drop the bundles key)
- Modify: `manifests/test/shared/base.toml`
- Delete: `manifests/test/shared/{dotfiles,util,extras,extbundle}.toml`
- Modify: `taskfiles/test.yml` (drop `--shared-dir`)
- Modify: `manifests/test/README.md`

**Interfaces:**
- Consumes: `--base` (Task 1), `feature_bucket` (Task 2), the redundancy rule
  (Task 4).
- Produces: a fixture suite that exercises base + feature + machine merging with
  no bundle involvement, so Task 6 can delete the bundle machinery without
  losing coverage.

- [ ] **Step 1: Make packages.bundles optional**

In `install/resolver.zsh`'s `validate_manifest`, replace the whole
`packages.bundles` validation block (lines 298-349, from the
`# packages.bundles: non-empty !!seq ...` comment through its closing `fi`) with:

```zsh
  # packages.bundles (optional, removed in schema 3): when present it must be an
  # array and every name must resolve to a bundle file. The non-empty and
  # must-include-dotfiles rules are gone -- a manifest may omit the key entirely.
  local bundles_present bundles_tag
  bundles_present=$(yq '.packages | has("bundles")' "$machine_file" 2>/dev/null || echo false)
  if [[ "$bundles_present" == "true" ]]; then
    bundles_tag=$(yq '.packages.bundles | tag' "$machine_file" 2>/dev/null || echo "")
    if [[ "$bundles_tag" != "!!seq" ]]; then
      error "packages.bundles must be an array; got tag: ${bundles_tag}"
      errors=$(( errors + 1 ))
    else
      local -a bundle_names=()
      read_nonempty_lines bundle_names < <(yq -r '.packages.bundles[]' "$machine_file" 2>/dev/null || true)
      local bn shared_toml available
      for bn in "${bundle_names[@]}"; do
        [[ -z "$bn" ]] && continue
        if ! [[ "$bn" =~ $PATH_NAME_RE ]]; then
          error "invalid bundle name '${bn}' (must match ${PATH_NAME_RE}; path-traversal guard)"
          errors=$(( errors + 1 ))
          continue
        fi
        shared_toml="${SHARED_DIR}/${bn}.toml"
        if [[ ! -f "$shared_toml" ]]; then
          available=$(print -l "${SHARED_DIR}"/*.toml(N:t:r) 2>/dev/null | tr '\n' '|' | sed 's/|$//')
          error "packages.bundles entry '${bn}' has no file at ${shared_toml} (available: ${available:-<none>})"
          errors=$(( errors + 1 ))
        fi
      done
    fi
  fi
```

- [ ] **Step 2: Extend the test base tier**

Replace the `[packages]` table in `manifests/test/shared/base.toml` with:

```toml
[packages]
formulae = [
  "curl",
  "git",
]
casks = []
mas = []
```

- [ ] **Step 3: Rewrite typed-01 through typed-04 onto base and flags**

`manifests/test/fixtures/typed-01-baseline/machine.toml` -- replace the header
comment and delete the `bundles` array:

```toml
# typed-01-baseline -- the base tier folds in with no packages declared anywhere
# else. Proves the resolver pipeline runs end-to-end with --registry and --base
# overrides and backfills arch via uname -m.

schema_version = 2

[machine]
description = "typed-01-baseline fixture"
os = "darwin"
identity = "none"

[features]
enabled = []
disabled = []

[packages]
```

In its `expected.json`, delete the `"bundles"` key and set
`.packages.brew.formulae` to `["curl", "git"]`.

`typed-02-formulae-dedup` -- the machine can no longer re-declare a base package
(the redundancy rule forbids it), so string dedup is exercised by an enabled
flag that overlaps the base tier instead. Create
`typed-02-formulae-dedup/features.toml`:

```toml
# Registry for typed-02: an enabled flag re-declares git, which the base tier
# already provides. Flag-vs-base overlap is legal (only MACHINE entries are
# subject to the redundancy rule) and is the real-world dedup case --
# one-password-ssh and one-password-signing both declare 1password.

[dup-flag]
description = "test flag whose formulae overlap the base tier"

[dup-flag.packages]
formulae = [
  "git",
  "ripgrep",
]
```

`typed-02-formulae-dedup/machine.toml`:

```toml
# typed-02-formulae-dedup -- bare formulae union across the base tier, an
# enabled flag, and the machine. Base declares curl + git; the flag re-declares
# git and adds ripgrep; the machine adds fzf. `add | unique` collapses the
# duplicate git. Expected: [curl, fzf, git, ripgrep].

schema_version = 2

[machine]
description = "typed-02-formulae-dedup fixture"
os = "darwin"
identity = "none"

[features]
enabled = [
  "dup-flag",
]
disabled = []

[packages]
formulae = [
  "fzf",
]
```

In its `expected.json`: delete `"bundles"`; set `.features` to
`{"dup-flag": true}`; set `.packages.brew.formulae` to
`["curl", "fzf", "git", "ripgrep"]`.

`typed-03-casks-mas-dedup` -- the bundle-supplied cask and mas entry move to a
flag. Create `typed-03-casks-mas-dedup/features.toml`:

```toml
# Registry for typed-03: an enabled flag supplies a cask and a mas entry whose
# id overlaps the machine's, locking in the feature-vs-machine union and the
# machine-wins mas dedup.

[extras-flag]
description = "test flag supplying a cask and a mas entry"

[extras-flag.packages]
casks = ["iterm2"]
mas = [{ id = 497799835, name = "Xcode-bundle" }]
```

`typed-03-casks-mas-dedup/machine.toml`:

```toml
# typed-03-casks-mas-dedup -- casks are bare strings unioned across an enabled
# flag (iterm2) and the machine (vscode) then wrapped to { name } objects on
# output; mas dedupes by .id with the machine winning (id 497799835 resolves to
# "Xcode-machine", not the flag's "Xcode-bundle"). mas is exempt from the
# redundancy rule precisely so this override stays legal.

schema_version = 2

[machine]
description = "typed-03-casks-mas-dedup fixture"
os = "darwin"
identity = "none"

[features]
enabled = [
  "extras-flag",
]
disabled = []

[packages]
casks = [
  "vscode",
]
mas = [
  { id = 497799835, name = "Xcode-machine" },
]
```

In its `expected.json`: delete `"bundles"`; set `.features` to
`{"extras-flag": true}`; formulae stays `["curl", "git"]`; casks stays
`[{"name":"iterm2"},{"name":"vscode"}]`; mas stays
`[{"id":497799835,"name":"Xcode-machine"}]`.

`typed-04-vscode-union` -- two enabled flags overlap on one extension, which is
how the production registry behaves (`one-password-ssh` and
`one-password-signing` both declare `1password`). Create
`typed-04-vscode-union/features.toml`:

```toml
# Registry for typed-04: two enabled flags whose vscode buckets overlap on
# acme.shared-dup, locking in cross-flag union + dedupe. This mirrors the
# production registry, where one-password-ssh and one-password-signing both
# declare the 1password cask.

[ext-flag-a]
description = "test flag supplying vscode extensions"

[ext-flag-a.packages]
vscode = [
  "acme.from-flag-a",
  "acme.shared-dup",
]

[ext-flag-b]
description = "second test flag overlapping ext-flag-a"

[ext-flag-b.packages]
vscode = [
  "acme.shared-dup",
]
```

`typed-04-vscode-union/machine.toml`:

```toml
# typed-04-vscode-union -- packages.vscode unions across two enabled flags
# (acme.from-flag-a, acme.shared-dup twice) and the machine
# (acme.from-machine), deduped by value. cargo/uv/npm stay empty, proving the
# resolver always materializes every bucket.

schema_version = 2

[machine]
description = "typed-04-vscode-union fixture"
os = "darwin"
identity = "none"

[features]
enabled = [
  "ext-flag-a",
  "ext-flag-b",
]
disabled = []

[packages]
vscode = [
  "acme.from-machine",
]
```

In its `expected.json`: delete `"bundles"`; set `.features` to
`{"ext-flag-a": true, "ext-flag-b": true}`; formulae stays `["curl", "git"]`;
extensions becomes
`["acme.from-flag-a","acme.from-machine","acme.shared-dup"]`.

- [ ] **Step 4: Drop the bundles key from typed-05, typed-06, and every negative fixture**

```bash
cd /Users/josh/Git/personal/dotfiles/manifests/test/fixtures
grep -rln 'bundles' --include='machine.toml' .
```

For each hit, delete the `bundles = [ ... ]` array (and the now-empty
`[packages]` table's trailing blank lines, but keep the `[packages]` header --
`_invalid-*` fixtures that assert on other errors must still parse).

In `typed-05-feature-packages/expected.json` and
`typed-06-base-tier/expected.json`, delete the `"bundles"` key.

Exception: `_invalid-bundle-typo` and `_invalid-bundles-no-dotfiles` exist only
to test rules this task removed. Delete both directories:

```bash
git rm -r _invalid-bundle-typo _invalid-bundles-no-dotfiles
```

`_invalid-missing-bundles` likewise tests the now-removed required-field rule.
Delete it too:

```bash
git rm -r _invalid-missing-bundles
```

- [ ] **Step 5: Delete the test bundle files and drop --shared-dir from the runner**

```bash
cd /Users/josh/Git/personal/dotfiles
git rm manifests/test/shared/dotfiles.toml manifests/test/shared/util.toml \
       manifests/test/shared/extras.toml manifests/test/shared/extbundle.toml
```

In `taskfiles/test.yml`, delete the `test_shared_dir=` line and the
`--shared-dir "$test_shared_dir" \` line from the typed-fixture invocation.
Update the typed-fixture comment block (lines 145-152) to read:

```
        # Typed-bucket positive fixtures (typed-*/): invoke the REAL resolver
        # via --stdout and diff against expected.json. Each fixture has:
        #   machine.toml  -- a full manifest
        #   expected.json -- golden resolved output
        #   features.toml -- optional registry override (else the real registry)
        # The base tier resolves to manifests/test/shared/base.toml via --base.
        # Exercises the whole pipeline: base fold + enabled-feature packages +
        # per-bucket union/dedup + emit.
```

- [ ] **Step 6: Update the fixture README**

```bash
grep -n 'bundle\|shared' manifests/test/README.md
```

Rewrite every hit: `manifests/test/shared/` now holds a single `base.toml`
supplying the base tier via `--base`; fixtures exercise feature-declared
packages through their own `features.toml`.

- [ ] **Step 7: Run the suite**

```bash
task test
```

Expected: every typed fixture passes and every remaining negative fixture is
correctly rejected; summary reports zero failures.

- [ ] **Step 8: Verify real machines are still byte-identical**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout \
    | jq -S 'del(.features)' > "/tmp/manifest-after-t5-${m}.json"
  if diff -q <(jq -S 'del(.features)' "/tmp/manifest-baseline/${m}.json") \
             "/tmp/manifest-after-t5-${m}.json" >/dev/null; then
    echo "OK   $m"
  else
    echo "FAIL $m"
    diff <(jq -S 'del(.features)' "/tmp/manifest-baseline/${m}.json") \
         "/tmp/manifest-after-t5-${m}.json"
  fi
done
```

Expected: four `OK` lines. `.features` is excluded because Task 3 legitimately
added two keys to it. Machines still declare bundles; only fixtures moved.

- [ ] **Step 9: Full verification and commit**

```bash
task lint && task test
```

```bash
git add -A
git commit -m "test(manifests): fixtures exercise base and feature tiers"
```

## Task 6: Cut the machines over and delete the bundle machinery

**Files:**
- Modify: `manifests/machines/{personal-laptop,work-laptop,atium,ci}.toml`
- Modify: `install/resolver.zsh`
- Modify: `manifests/test/fixtures/*/machine.toml` (schema 3)
- Modify: `manifests/test/fixtures/typed-*/expected.json` (drop `bundles`)
- Delete: `manifests/bundles/` (6 TOML files + README.md)

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: schema 3; `resolved.json` without `packages.brew.bundles`; a
  resolver with no bundle concept. Task 7 documents the result.

- [ ] **Step 1: Rewrite personal-laptop**

Replace `manifests/machines/personal-laptop.toml` entirely:

```toml
# manifests/machines/personal-laptop.toml -- Josh's personal MacBook.
#
# Self-contained: every feature this machine has (and every registry flag it
# deliberately lacks) is listed below; nothing is inherited.
#
# [packages] lists discretionary choices only -- applications wanted on this
# machine. Packages required by the dotfiles config itself are not listed here:
# unconditional tooling lives in manifests/base.toml, and a feature's own
# dependencies live on its flag in manifests/features.toml. Listing a package
# that base or an enabled flag already provides is a hard error.
#
# Schema reference: docs/MANIFEST.md.

schema_version = 3

[machine]
description = "Josh's personal MacBook -- Apple Silicon, primary dev machine"
os = "darwin"
arch = "arm64"
identity = "personal"

[features]
enabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "repo-auto-update",
  "repo-dev-toolchain",
  "ghostty",
  "vscode",
  "jgrid-net",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-spotlight",
  "macos-screenshots",
  "macos-security",
  "macos-appearance",
  "macos-display",
]
disabled = [
  "server-include",
]

[packages]
# container: Apple's container runtime; requires macOS 15+, so machines on
# older releases must not list it.
# node: the ecc Claude addon's hooks invoke the `node` binary directly.
formulae = [
  "bat",
  "bottom",
  "container",
  "doggo",
  "duf",
  "fd",
  "gh",
  "git-crypt",
  "htop",
  "hugo",
  "node",
  "poppler",
  "uv",
  "wget",
]

casks = [
  "1password-cli",
  "alcove",
  "appcleaner",
  "cardhop",
  "claude-code",
  "cloudflare-warp",
  "discord",
  "dropbox",
  "fantastical",
  "firefox",
  "gitfox",
  "microsoft-excel",
  "microsoft-powerpoint",
  "microsoft-word",
  "miniconda",
  "nvidia-geforce-now",
  "proton-drive",
  "proton-mail",
  "protonvpn",
  "raycast",
  "slack",
  "spotify",
  "standard-notes",
  "sublime-text",
  "zoom",
]

mas = [
  { id = 441258766, name = "Magnet" },
  { id = 904280696, name = "Things3" },
]
```

- [ ] **Step 2: Rewrite work-laptop**

Replace `manifests/machines/work-laptop.toml`'s `schema_version`, `[features]`,
and `[packages]` sections (keep its existing header comment's first line and
`[machine]` block verbatim; add the same three-paragraph `[packages]` note used
above):

```toml
schema_version = 3

[features]
enabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "repo-auto-update",
  "repo-dev-toolchain",
  "ghostty",
  "vscode",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-screenshots",
  "macos-security",
  "macos-appearance",
  "macos-display",
]
disabled = [
  "jgrid-net",
  "macos-spotlight",
  "server-include",
]

[packages]
# container: Apple's container runtime; requires macOS 15+.
formulae = [
  "bat",
  "bottom",
  "container",
  "doggo",
  "duf",
  "fd",
  "gh",
  "git-crypt",
  "htop",
  "hugo",
  "poppler",
  "uv",
  "wget",
]

casks = [
  "1password-cli",
  "alcove",
  "appcleaner",
  "cardhop",
  "claude-code",
  "fantastical",
  "firefox",
  "gitfox",
  "microsoft-excel",
  "microsoft-powerpoint",
  "microsoft-word",
  "miniconda",
  "raycast",
  "slack",
  "spotify",
  "standard-notes",
  "sublime-text",
  "zoom",
]

mas = [
  { id = 441258766, name = "Magnet" },
  { id = 904280696, name = "Things3" },
]
```

- [ ] **Step 3: Rewrite atium**

Replace `manifests/machines/atium.toml`'s `schema_version`, `[features]`, and
`[packages]` sections (keep its header comment and `[machine]` block):

```toml
schema_version = 3

[features]
enabled = [
  "repo-auto-update",
  "ghostty",
  "macos-security",
]
disabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "repo-dev-toolchain",
  "vscode",
  "jgrid-net",
  "server-include",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-spotlight",
  "macos-screenshots",
  "macos-appearance",
  "macos-display",
]

[packages]
# 1password is listed here rather than arriving via one-password-ssh/-signing:
# identity/ssh/identities/atium uses the local system ssh-agent, not 1Password,
# so those flags stay off while the application itself is still wanted.
# container is intentionally absent -- it requires macOS 15+ and this machine
# runs Sonoma 14.
formulae = [
  "bat",
  "bottom",
  "doggo",
  "duf",
  "fd",
  "gh",
  "git-crypt",
  "htop",
  "hugo",
  "poppler",
  "wget",
]

casks = [
  "1password",
  "appcleaner",
  "cloudflare-warp",
  "dropbox",
  "miniconda",
  "orbstack",
]
```

- [ ] **Step 4: Rewrite ci**

Replace `manifests/machines/ci.toml`'s `schema_version`, `[features]`, and
`[packages]` sections (keep its header comment and `[machine]` block):

```toml
schema_version = 3

[features]
enabled = [
  "repo-dev-toolchain",
]
disabled = [
  "one-password-ssh",
  "one-password-signing",
  "claude-marketplace",
  "repo-auto-update",
  "ghostty",
  "vscode",
  "jgrid-net",
  "server-include",
  "macos-dock",
  "macos-finder",
  "macos-input",
  "macos-spotlight",
  "macos-screenshots",
  "macos-security",
  "macos-appearance",
  "macos-display",
]

[packages]
# repo-dev-toolchain is enabled: this machine runs task lint and task test, so
# it needs the lint and format tooling that flag carries.
formulae = [
  "bat",
  "bottom",
  "doggo",
  "duf",
  "fd",
  "gh",
  "git-crypt",
  "htop",
  "hugo",
  "poppler",
  "wget",
]
```

- [ ] **Step 5: Bump schema_version to 3 in the resolver**

In `install/resolver.zsh`'s `validate_manifest`, replace the schema check:

```zsh
  # schema_version must be present and equal 3.
  local schema_value
  schema_value=$(yq -r '.schema_version // ""' "$machine_file" 2>/dev/null || echo "")
  if [[ -z "$schema_value" ]]; then
    error "missing required field: schema_version (must equal 3)"
    errors=$(( errors + 1 ))
  elif [[ "$schema_value" == "2" ]]; then
    error "schema_version 2 is no longer supported -- packages.bundles was removed; declare discretionary packages inline (see docs/MANIFEST.md) and set schema_version = 3"
    errors=$(( errors + 1 ))
  elif [[ "$schema_value" != "3" ]]; then
    error "schema_version must equal 3; got: ${schema_value}"
    errors=$(( errors + 1 ))
  fi
```

- [ ] **Step 6: Remove the bundle machinery**

In `install/resolver.zsh`, make these deletions:

1. Delete the `SHARED_DIR` declaration (line 27) and update the header banner's
   `Purpose:` line to drop "the bundle set (manifests/bundles/),".
2. Delete `"packages.bundles"` from the `ALLOWED_KEYS` array.
3. Delete the entire `bundle_files_for()` function.
4. Delete the whole `packages.bundles` validation block added in Task 5 Step 1.
5. In `resolve_pipeline`, delete the `bundles_json` assignment, the
   `local -a bundle_files=()` declaration, and the `bundle_files_for ... || return 1`
   call.
6. Change the seven `union_bucket` call sites to drop the trailing
   `"${bundle_files[@]}"` argument.
7. Simplify `union_bucket` to its final form:

```zsh
# union_bucket <machine_file> <key> <finalize_jq> <feature_json>
# Concatenate the .packages.<key> arrays from the base tier, then the
# enabled-feature packages, then the machine, and apply the finalize jq
# expression. Bare-string buckets use `add | unique`; casks wrap to { name }
# objects; mas dedupes by .id (last wins, so the machine overrides base or a
# feature).
union_bucket() {
  local machine_file="$1" key="$2" finalize="$3" feature_json="$4"
  {
    yq -o=json ".packages.${key} // []" "$BASE_TOML"
    printf '%s\n' "${feature_json:-[]}"
    yq -o=json ".packages.${key} // []" "$machine_file"
  } | jq -s "$finalize"
}
```

8. In the final `jq -n` assembly, delete the `--argjson bundles "$bundles_json"`
   line and the `bundles: $bundles,` field, and update the trailing comment to:

```zsh
  # Assemble the resolved.json contract. schema_version is intentionally
  # omitted -- nothing consumes it. packages.brew.{formulae,casks,mas} hold the
  # full brew package set (base tier + enabled-feature packages + machine).
```

9. Delete the `--shared-dir` case from `main()`'s arg parser and its line from
   the `--help` heredoc.

- [ ] **Step 7: Bump every fixture to schema 3 and drop bundles from expected output**

```bash
cd /Users/josh/Git/personal/dotfiles/manifests/test/fixtures
grep -rln 'schema_version = 2' . | while IFS= read -r f; do
  sed -i '' 's/^schema_version = 2$/schema_version = 3/' "$f"
done
grep -rn 'schema_version' . | grep -v 'schema_version = 3' || echo "all fixtures at schema 3"
```

Exception: `_invalid-wrong-schema-version` and `_invalid-missing-schema-version`
test the schema rule itself. Inspect both and adjust so they still fail for the
right reason -- `_invalid-wrong-schema-version` should declare a value that is
neither 2 nor 3 (use `schema_version = 99`) and its `expect.txt` line 1 should
read `schema_version must equal 3`.

Then drop the `bundles` key from every typed fixture's golden output:

```bash
for f in typed-*/expected.json; do
  jq 'del(.packages.brew.bundles)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
```

- [ ] **Step 8: Delete the bundles directory**

```bash
cd /Users/josh/Git/personal/dotfiles
git rm -r manifests/bundles
```

- [ ] **Step 9: Run the suite**

```bash
task test
task lint
```

Expected: both pass.

- [ ] **Step 10: Verify the prune diff -- the phase gate**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  echo "=== $m ==="
  DOTFILEDIR="$PWD" zsh install/resolver.zsh --machine "$m" --stdout | jq -S . \
    > "/tmp/manifest-final-${m}.json"
  diff <(jq -S 'del(.features, .packages.brew.bundles)' "/tmp/manifest-baseline/${m}.json") \
       <(jq -S 'del(.features)' "/tmp/manifest-final-${m}.json") \
    && echo "  identical"
done
```

Expected output, exactly:

- `personal-laptop`: `identical`
- `work-laptop`: `identical`
- `atium`: seven removals -- `biome`, `hyperfine`, `ruff`, `shellcheck`,
  `shfmt`, `taplo` from formulae and `{"name":"1password-cli"}` from casks
- `ci`: one removal -- `{"name":"1password-cli"}` from casks

If any other line appears, stop and diagnose before continuing.

- [ ] **Step 11: Confirm the resolved totals**

```bash
cd /Users/josh/Git/personal/dotfiles
for m in personal-laptop work-laptop atium ci; do
  printf '%-16s %s\n' "$m" "$(jq '[.packages.brew.formulae, .packages.brew.casks, .packages.brew.mas, .packages.vscode.extensions] | map(length) | add' "/tmp/manifest-final-${m}.json")"
done
```

Expected: `personal-laptop 101`, `work-laptop 93`, `atium 40`, `ci 39`.

- [ ] **Step 12: Converge this machine**

```bash
task install
```

Expected: completes with no package installs or removals -- personal-laptop's
resolved set is unchanged, so `brew bundle` is a no-op.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat(manifests)!: machine manifests declare packages directly"
```

## Task 7: Documentation

**Files:**
- Modify: `docs/MANIFEST.md`
- Modify: `CLAUDE.md`
- Modify: `manifests/README.md`
- Modify: `manifests/machines/README.md`
- Modify: `docs/NIXOS-ARCHITECTURE-LEARNINGS.md`
- Modify: `docs/superpowers/plans/2026-07-23-nixos-architecture-improvements.md`

**Interfaces:**
- Consumes: the finished implementation from Tasks 1-6.
- Produces: nothing consumed by later tasks; this is the last task.

- [ ] **Step 1: Find every stale reference**

```bash
cd /Users/josh/Git/personal/dotfiles
grep -rn 'bundle' --include='*.md' --include='*.yml' --include='*.zsh' --include='*.toml' . \
  | grep -v '^./.git/' \
  | grep -v 'docs/superpowers/specs/' \
  | grep -v 'brew bundle' \
  | grep -v 'application bundle' \
  | grep -v '\.app bundle'
```

`brew bundle`, "application bundle", and the 1Password ".app bundle" comments
are live functional references and must be kept. Everything else naming the
removed bundle layer must go. `docs/superpowers/specs/*` are dated historical
records -- leave them untouched.

- [ ] **Step 2: Rewrite docs/MANIFEST.md**

Make these changes:

1. In "What This Is", replace "Package bundles live under `manifests/bundles/`"
   with a sentence naming the three tiers: unconditional `manifests/base.toml`,
   feature-owned `[<flag>.packages]` in `manifests/features.toml`, and
   discretionary `[packages]` in a machine manifest.
2. In the machine manifest shape block, set `schema_version = 3` and delete the
   `bundles = [ ... ]` lines and their comment.
3. Delete the "Bundle shape (`manifests/bundles/<name>.toml`)" section. Replace
   it with a "Base tier (`manifests/base.toml`)" section documenting the same
   `[packages]` shape and the rule that no machine declares it.
4. In "Required fields", delete the `packages.bundles` row.
5. In "Optional fields", change the `packages.formulae / casks / ...` row's
   description from "unioned with the included bundles" to "unioned with the
   base tier and every enabled feature's packages".
6. In "Package resolution", replace the bundle-union prose with the three-tier
   union order (base, then enabled features, then machine) and the mas
   last-wins note. Delete the "The `dotfiles` bundle is mandatory" paragraph.
7. In "Compiled output", delete the `packages.brew.bundles` sentence.
8. Add a "Feature-declared packages" subsection to the feature registry section:

```markdown
### Feature-declared packages

A registry flag may declare the packages its concern needs:

    [ghostty]
    description = "gate shell/aliases/ghostty.zsh and the ghostty config link"

    [ghostty.packages]
    casks = ["ghostty"]

Buckets mirror the base and machine `[packages]` shape (`formulae`, `casks`,
`mas`, `vscode`, `cargo`, `uv`, `npm`). When a machine enables the flag, the
resolver unions these into the resolved set; a disabled flag contributes
nothing. Machines list applications you want; a feature's own tooling belongs
on the flag, so enabling the feature guarantees its tools.

A machine may not list a package the base tier or an enabled flag already
provides -- the resolver rejects it. `mas` is exempt so a machine can override
an entry by id.
```

9. In "Adding a New Machine", replace any bundle-selection step with "list the
   applications you want in `[packages]`".

- [ ] **Step 3: Rewrite CLAUDE.md**

1. In "The Manifest Model" table, replace the "Shared package bundles" row with
   "Unconditional package tier | `manifests/base.toml`".
2. In "Where to Add Things", replace the brew-package row with:
   `| A brew package | The machine's own `[packages]` (an app you want), a flag's `[<flag>.packages]` (a feature's own tooling), or `manifests/base.toml` (needed by every machine) | by tier, not by machine |`
   and the VSCode-extension row's destination with `[vscode.packages] vscode` in
   `manifests/features.toml`.
3. In the feature-flag row, add "a flag may declare `[<flag>.packages]` buckets
   the resolver unions in when enabled".
4. In "Don't Do", delete the "Don't add a profile-suffixed bundle" bullet and
   replace it with: "Don't list a package in a machine manifest that
   `manifests/base.toml` or an enabled flag already provides -- the resolver
   rejects it. Machine manifests record deliberate choices only."
5. In "Manifests are the source of truth", after the feature-accounting
   paragraph, add a sentence naming the three tiers and the invariant that a
   package appears in a machine file if and only if it was a free choice.

- [ ] **Step 4: Update the remaining READMEs**

`manifests/README.md` -- replace the `bundles/` directory entry with `base.toml`
and describe the three tiers.

`manifests/machines/README.md` -- drop any bundle-selection guidance; describe
`[packages]` as discretionary-only and name the redundancy rule.

- [ ] **Step 5: Reconcile the learnings doc**

In `docs/NIXOS-ARCHITECTURE-LEARNINGS.md` section C ("Bundles vs machine TOML"),
replace the body with a short note that the concern is resolved: the three-tier
split landed, bundles are gone, and a flag declaring its own packages is the
module-system lesson applied. Keep the section heading so the A-E structure
stays intact.

- [ ] **Step 6: Delete the subsumed task from the old plan**

In `docs/superpowers/plans/2026-07-23-nixos-architecture-improvements.md`:

1. Delete the entire "## Phase 4 -- Feature-declared packages" section
   including Task 8 and all its steps.
2. In the intro paragraph, delete the sentence "Phase 4 lets a registry flag
   declare the packages it needs, folded in by the resolver." and change "Four
   phases" to "Three phases".
3. In "Target layout", delete the
   `(+ typed-05-feature-packages, Phase 4)` annotation.
4. In the self-review checklist, change the spec-coverage line's
   "C feature packages (Task 8)" to "C feature packages (delivered by
   docs/superpowers/plans/2026-08-02-manifest-tier-restructure.md)".

- [ ] **Step 7: Verify no stale references remain**

Re-run the Step 1 grep.

Expected: only `brew bundle`, "application bundle", and ".app bundle" hits
remain.

- [ ] **Step 8: Full verification and commit**

```bash
task lint && task test
```

Expected: both pass, including LINT-08 banner parity (no new public task was
added, so the banner is untouched).

```bash
git add -A
git commit -m "docs(manifests): document the three package tiers"
```

---

## Self-review notes

**Spec coverage:** three tiers (Tasks 1-3, 6); schema v3 (Task 6); resolver
removals and additions (Tasks 1, 2, 4, 6); union order (Tasks 1, 6);
redundancy rule (Task 4); output contract (Task 6); fixture impact (Tasks 1, 2,
5, 6); two-phase migration with `resolved.json` gates (Task 1 Step 1 baseline;
Tasks 1, 2, 3, 5 invariant checks; Task 6 Step 10 prune gate); verification
table (Task 6 Steps 9-12); relationship to the existing plan (Task 7 Step 6).

**Known judgment calls, resolved:**

- `mas` is exempt from the redundancy rule. Without the exemption, the
  documented machine-wins-by-id override becomes unexpressible and typed-03's
  assertion would be impossible to write.
- The redundancy error message uses `'` rather than a literal apostrophe:
  the jq program is inside a single-quoted shell string, so a bare `'` would
  terminate it.
- Phase A's Task 3 changes the `features` map by two keys on every machine.
  That is a real, expected diff and Step 5 checks packages and features
  separately rather than pretending the whole document is unchanged.
- `_invalid-bundle-typo`, `_invalid-bundles-no-dotfiles`, and
  `_invalid-missing-bundles` are deleted rather than rewritten -- they test
  rules that no longer exist, and there is nothing to port them to.
- Task 6 Step 6 changes `union_bucket`'s arity a second time (Task 1 added the
  feature arg while keeping bundle varargs; Task 6 drops the varargs). Two edits
  to one function is the cost of keeping Phase A provably additive.
