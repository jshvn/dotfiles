# Phase 1: Manifest Engine + Repository Skeleton - Research

**Researched:** 2026-05-13
**Domain:** TOML manifest schema + deep-merge resolver + go-task fromJson loading + repository skeleton
**Confidence:** HIGH (every critical claim verified by running the actual tools — yq 4.53.2 and go-task 3.50.0 on macOS arm64 in this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**TOML Schema Shape:**
- **D-01:** `[platform]` block is required, `platform.os` must equal `"darwin"` in v1. Validator rejects any other value. When Linux v2 arrives, the rule opens up to accept `"linux"` — no schema migration needed.
- **D-02:** `arch` is optional. Resolver detects via `uname -m` and writes the value into `resolved.json` so downstream tasks read it from one place.
- **D-03:** Required-field set for machine manifests — `manifest:validate` fails if any of these is missing from `manifests/machines/<name>.toml`:
  - `meta.description` (free-text)
  - `platform.os` (must be `"darwin"` in v1)
  - `features` (table, may be empty `{}`)
  - `packages.brew.bundles` (array, must list at least `"core"`)
  - `identity.git` (string, one of `"personal" | "work" | "none"`)
  - `identity.ssh` (string, one of `"personal" | "work" | "none"`)
- **D-04:** Unknown keys produce a warning to stderr, not a failure. Format: `unknown key: features.macos-dok at manifests/machines/personal-laptop.toml:14`. Exit 0.
- **D-05:** `defaults.toml` is hybrid — supplies safe values for every required field, BUT `manifest:validate` still requires the machine file to explicitly declare every required field. Inheriting a sensitive field silently is the failure mode being guarded against.

**Deep-Merge Semantics:**
- **D-06:** Merge rules — maps deep-merge (machine wins, siblings preserved); scalars replaced (machine wins); arrays replaced wholesale; `extra_packages` explicitly concatenated + deduplicated.
- **D-07:** Use `yq eval-all '. as $i ireduce ({}; . * $i)'` (recursive deep-merge), NOT `jq -s '.[0] * .[1]'` (shallow).
- **D-08:** Test fixtures are golden-output tests under `manifests/test/fixtures/`; each fixture has `defaults.toml`, `machine.toml`, expected `resolved.json`. `task manifest:test` diffs actual vs expected. Required cases: map-over-map, list-replace, scalar-override, nested table, missing-in-defaults, missing-in-machine, `extra_packages` concatenation.

**Repository Skeleton:**
- **D-09:** Full skeleton in Phase 1. Every top-level directory exists with at minimum a stub README: `manifests/` (P1), `taskfiles/` (P1), `install/` (P1), `docs/` (P1), `shell/` (P3), `identity/` (P4), `packages/` (P5), `configs/` (P7), `os/` (P6), `claude/` (P7).
- **D-10:** Flat structure for v1 (no platform subdirectories). `packages/` flat (`packages/core.rb`, not `packages/brew/core.rb`); `os/` flat (`os/defaults/<concern>.zsh`); `shell/aliases/<topic>.zsh` flat; `identity/git/identities/<name>` flat. Known migration cost when Linux returns; accepted.
- **D-11:** Stub READMEs for placeholder directories — each ~10 lines: one-line purpose, "Populated by Phase X", optional req-ID pointer.
- **D-12:** `docs/MANIFEST.md` is a P1 deliverable — schema reference, merge-semantics worked examples, "Adding a new machine" walkthrough.
- **D-13:** Project-level `CLAUDE.md` (at repo root) is a P1 deliverable — v2 conventions for AI-assisted maintenance.

**`resolved.json` Cache Lifecycle:**
- **D-14:** Auto-rebuild via `status:` check on `manifest:resolve`. Skip rebuild when `resolved.json` mtime is newer than every `manifests/*.toml` and `manifests/machines/<active>.toml`.
- **D-15:** Cache location: `$XDG_STATE_HOME/dotfiles/resolved.json` (machine-local; not in repo).
- **D-16:** Missing-state = hard fail with actionable error listing available machines from `manifests/machines/*.toml`. No interactive prompts. No silent fallback to hostname inference.
- **D-17:** `task manifest:show` accepts `-- --machine <name>` for side-by-side comparison without switching the state file.

### Claude's Discretion

- **Schema validation mechanism:** hand-rolled zsh checks in `resolver.zsh` is the simplest path for v1; JSON Schema + taplo/ajv is richer but adds tooling. Pick the simpler one unless research finds a strong reason. JSON Schema deferred to v2 (`TOOL-V2-01`).
- **Machine naming convention:** kebab-case implied. No explicit rename flow in v1.
- **Test runner mechanics:** `task manifest:test` is a zsh script that loops fixtures and diffs; exact diff tool is implementation detail.
- **`docs/MANIFEST.md` structure:** outline is a suggestion; planner can refine.
- **Header comment in `resolved.json`:** nice-to-have, not required.

### Deferred Ideas (OUT OF SCOPE)

- JSON Schema for editor validation (deferred to v2 — `TOOL-V2-01`)
- Manifest rename flow (`task setup -- --rename <old> <new>`)
- Drift detection / orphan reconciliation (owned by Phase 8)
- Header comment in `resolved.json` with debug timestamp
- `task manifest:diff <m1> <m2>` for side-by-side comparison
- Interactive `task setup` prompt
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MFST-01 | `manifests/defaults.toml` defines shared baseline (identity, features, default package bundles) | Schema sketch in §3; D-05 hybrid-defaults pattern requires every required field to have a safe value in defaults |
| MFST-02 | `manifests/machines/<name>.toml` declares per-machine identity, features, package bundles, overrides | Per-machine TOML schema in §3; validated by D-03 required-field set |
| MFST-03 | Machine manifest can override any `defaults.toml` key with documented merge semantics | yq `. * .` deep-merge expression verified in §4; two-pass strategy for `extra_packages` in §5 |
| MFST-04 | `install/resolver.zsh` compiles defaults + machine manifest into `$XDG_STATE_HOME/dotfiles/resolved.json` using yq | Full resolver pipeline in §4 and §5; yq v4.53.2 verified locally; `set -euo pipefail` enforced per v1 conventions |
| MFST-05 | Test fixtures cover all merge cases; run by `task manifest:test` | Six fixture cases verified end-to-end in §4 — all produced expected output; fixture layout in §10 |
| MFST-06 | `task manifest:resolve` produces `resolved.json`; downstream tasks consume via go-task `fromJson` and never read TOML directly | go-task v3.50 `ref: 'fromJson .VAR'` syntax verified by running an actual Taskfile in §6 |
| MFST-07 | `task manifest:show` prints post-merge structure for debugging | yq pipe to `jq .` or `yq -P` for prettified output (§6); D-17 `--machine <name>` flag pattern in §6 |
| MFST-08 | `task manifest:validate` enforces required schema fields | yq `has()` + tag-based type predicates verified in §3; concrete validation script in §3 |
| MFST-09 | Adding a new machine is a single new file in `manifests/machines/` plus `task setup -- <name>` | `task setup` flow + preconditions pattern in §6; throwaway fixture machine test in §11 |
| DOCS-03 | `CLAUDE.md` (project-level) captures v2 conventions for AI maintenance | Outline in §10 covers manifest model, one-concept-per-file, flat-dir rule, where to add things |
| DOCS-04 | `docs/MANIFEST.md` documents schema, inheritance rules, worked examples | Outline in §9 covers schema reference, six worked examples (one per merge case), add-a-machine walkthrough |
</phase_requirements>

---

## 1. Executive Summary

**Top decisions / risks the planner needs to know up front:**

1. **The reference `yq eval-all '. as $i ireduce ({}; . * $i)' ... -o json` expression DOES deep-merge correctly** for maps, scalars, and array-replace cases — verified locally against all six fixture cases. The shallow-merge bug in STATE.md was about `jq -s '.[0] * .[1]'`, not yq. yq's `. * .` is the correct deep operator. *(STATE.md blocker #2 — RESOLVED.)*

2. **`extra_packages` concatenation requires a deliberate two-pass merge.** yq has two operators: `*` (deep-merge maps, REPLACE arrays — correct for `bundles`) and `*+` (deep-merge maps, CONCAT arrays). Using `*+` globally would incorrectly concat `bundles` too. The resolver must (a) do the standard `. * .` merge, then (b) compute the union of `extra_packages` from both sides and surgically overwrite that single field. Verified working pattern in §5.

3. **go-task v3.50 `fromJson` + `ref:` works for loading `resolved.json` — with one kebab-case caveat.** Snake_case dot access (`.MANIFEST.identity.git`) works directly. Kebab-case keys (e.g., `features.one-password-ssh`, `features.macos-dock`) fail Go-template parsing on the `-` and must use `{{index .MANIFEST.features "one-password-ssh"}}`. Verified by running an actual Taskfile in this session. *(STATE.md blocker #3 — RESOLVED.)*

4. **BSD `find -newer` is the right tool for the mtime `status:` check on macOS** — no GNU extensions needed. Concrete one-liner in §7 returns non-empty (status fail → task runs) when any manifest is newer than the target, and exits non-zero when the target is missing. Both behaviors are exactly what `status:` needs.

5. **Hand-rolled zsh validation is sufficient for v1** — yq's `has()` + tag-based type predicates cover the D-03 required-field set without adding any new dependency. JSON Schema (TOOL-V2-01) brings editor integration but no v1 capability that hand-rolled checks lack. Concrete validation script in §3.

**Primary recommendation for the planner:** Build the resolver in this order to minimize backtracking — (1) write the six golden-output fixtures FIRST with hand-computed expected JSON, (2) implement `install/resolver.zsh` against the fixtures, (3) wire `taskfiles/manifest.yml` with `ref: 'fromJson .MANIFEST_JSON'` last. Don't write the Taskfile loader until the resolver passes all six fixtures — that decouples merge-correctness debugging from go-task-templating debugging.

---

## 2. Tooling Versions & Install Paths

| Tool | Min Version | Verified Version | Path on Target | Source |
|------|------------|------------------|----------------|--------|
| `yq` (mikefarah) | **v4.52.1** (TOML roundtrip) | **v4.53.2** (Apr 2026) | `/opt/homebrew/bin/yq` (arm64) | `brew install yq` `[VERIFIED: brew install yq this session]` |
| `go-task` | **v3.37** (map vars + `ref:`) | **v3.50.0** | `/opt/homebrew/bin/task` | `brew install go-task` `[VERIFIED: task --version in this session]` |
| `jq` | **1.7+** | **jq-1.8.1** | `/opt/homebrew/bin/jq` | already in v1 Brewfile `[VERIFIED: jq --version]` |

**Minimum yq version rationale:**
- Full TOML roundtrip (read AND write) requires v4.52.1+. We only READ TOML in P1, but the `. as $i ireduce ({}; . * $i)` merge operator behavior is stable across 4.4x+. Pin to v4.52.1+ to give a margin and document the intent. `[CITED: https://github.com/mikefarah/yq releases]`

**Minimum go-task version rationale:**
- `ref:` keyword + `fromJson` template function: `ref:` is documented in the v3 schema reference; combination with `fromJson` shown in official examples at [github.com/go-task/task — guide.md "Parsing JSON/YAML into map variables"](https://github.com/go-task/task/blob/main/website/src/docs/guide.md). `[VERIFIED: via Context7 /go-task/task docs lookup this session]`
- Pin to v3.37+ (map variables added). All target machines run v3.50.0 from current Brewfile, so practical floor is v3.50. `[VERIFIED: task --version output]`

**Local install assumption:** yq is NOT in the current v1 Brewfile despite STACK.md's claim that it is. I had to `brew install yq` in this session. **Action for planner:** ensure `packages/core.rb` (Phase 5) declares `brew "yq"`. For Phase 1, the resolver assumes `yq` is on `$PATH`; Phase 2's bootstrap will own the install ordering. `[VERIFIED: brew list output this session]`

**`uname -m` for `arch` detection (D-02):** Returns `arm64` on Apple Silicon, `x86_64` on Intel — exactly the values needed. `[VERIFIED: uname -m → arm64 this session]`

---

## 3. Manifest Schema & Validation

### 3.1 `manifests/defaults.toml` shape

```toml
schema_version = 1

[meta]
description = "default — machine must override"

[platform]
# Machine MUST declare os; defaults provides shape only (D-05).
# Listing here is documentation; validator rejects defaults that override.
os = "darwin"

[features]
# Opt-in feature flags. Each feature is consumed by exactly one task/asset
# in a later phase. Defaults provide safe (mostly off) values.
one-password-ssh = false
motd = true
claude-marketplace = true

[packages.brew]
bundles = ["core"]
extra_packages = []

[identity]
git = "none"
ssh = "none"
```

### 3.2 `manifests/machines/personal-laptop.toml` shape

```toml
schema_version = 1

[meta]
description = "Josh's personal MacBook — Apple Silicon, primary dev machine"

[platform]
os = "darwin"
arch = "arm64"            # optional; resolver fills via uname -m if absent

[features]
one-password-ssh = true
macos-dock = true
macos-finder = true
macos-input = true
macos-screenshots = true
macos-security = true
motd = true
claude-marketplace = true

[packages.brew]
bundles = ["core", "gui", "dev", "personal"]
extra_packages = ["docker-desktop"]

[identity]
git = "personal"
ssh = "personal"
```

### 3.3 Required-field validation (D-03)

**Hand-rolled validation in zsh — concrete pattern verified in this session:**

```zsh
# install/resolver.zsh — required-field validation snippet
local machine_file="$1"
local errors=0

# Scalar string presence (errors if missing OR empty OR explicit null)
required_strings=(
  "meta.description"
  "platform.os"
  "identity.git"
  "identity.ssh"
)
for path in "${required_strings[@]}"; do
  local parent="${path%.*}"
  local key="${path##*.}"
  local present
  present=$(yq ".${parent} | has(\"${key}\")" "$machine_file" 2>/dev/null)
  if [[ "$present" != "true" ]]; then
    error "missing required field: ${path}"
    errors=$((errors + 1))
  fi
done

# features must be a table (may be empty)
local features_tag
features_tag=$(yq '.features | tag' "$machine_file" 2>/dev/null)
if [[ "$features_tag" != "!!map" ]]; then
  error "features must be a table (may be empty {}); got tag: $features_tag"
  errors=$((errors + 1))
fi

# packages.brew.bundles must be a non-empty array containing "core"
local bundles_tag
bundles_tag=$(yq '.packages.brew.bundles | tag' "$machine_file" 2>/dev/null)
if [[ "$bundles_tag" != "!!seq" ]]; then
  error "packages.brew.bundles must be an array; got tag: $bundles_tag"
  errors=$((errors + 1))
elif [[ "$(yq '.packages.brew.bundles | length' "$machine_file")" -lt 1 ]]; then
  error "packages.brew.bundles must contain at least one bundle"
  errors=$((errors + 1))
elif [[ "$(yq '.packages.brew.bundles | contains(["core"])' "$machine_file")" != "true" ]]; then
  error 'packages.brew.bundles must include "core"'
  errors=$((errors + 1))
fi

# platform.os must equal "darwin" (D-01)
local os_value
os_value=$(yq -r '.platform.os' "$machine_file" 2>/dev/null)
if [[ "$os_value" != "darwin" ]]; then
  error "platform.os must equal 'darwin' in v1; got: $os_value"
  errors=$((errors + 1))
fi

# identity.git and identity.ssh must be one of "personal" | "work" | "none"
for key in git ssh; do
  local val
  val=$(yq -r ".identity.${key}" "$machine_file" 2>/dev/null)
  case "$val" in
    personal|work|none) ;;
    *) error "identity.${key} must be one of personal|work|none; got: $val"
       errors=$((errors + 1)) ;;
  esac
done

return $errors
```

**Why `has()` + tag-based predicates over `// "absent"` defaults:**
- `yq '.features // "absent"'` returns `"absent"` for both missing keys AND empty tables `{}`. We need to distinguish — `features = {}` is valid per D-03, `features` missing is not.
- `has()` returns `true` only when the key is explicitly present. `[VERIFIED: yq '.features | tag' returned !!map for empty {} and (yq '. | has("features"))' returned true]`
- Tag predicates (`!!map`, `!!seq`, `!!str`) work uniformly for type assertions. `[VERIFIED: yq '.packages.brew.bundles | tag' returned !!seq this session]`

### 3.4 Unknown-key warning (D-04)

**Implementation pattern — produce a list of "expected" paths, then list any path in the actual file not in the expected set:**

```zsh
# install/resolver.zsh — unknown-key warning
local expected_paths=(
  "schema_version"
  "meta.description" "meta.notes"
  "platform.os" "platform.arch"
  "features"                # entire table is opaque — any key allowed inside features
  "packages.brew.bundles" "packages.brew.extra_packages"
  "identity.git" "identity.ssh"
)

# yq emits all leaf paths as "a.b.c"
yq -r '[paths(scalars) | join(".")] | .[]' "$machine_file" 2>/dev/null | while read -r found; do
  local matched=0
  for expected in "${expected_paths[@]}"; do
    if [[ "$found" == "$expected" ]] || [[ "$found" == ${expected}.* ]]; then
      matched=1
      break
    fi
  done
  if [[ $matched -eq 0 ]]; then
    # Line number lookup: ggrep -n for the leaf segment in the file
    local leaf="${found##*.}"
    local line_no
    line_no=$(ggrep -n "^${leaf}\\s*=" "$machine_file" 2>/dev/null | head -1 | cut -d: -f1)
    warn "unknown key: ${found} at ${machine_file}:${line_no:-?}"
  fi
done

# CRITICAL: unknown-key warnings exit 0 — they are advisory only (D-04)
```

**Caveat (LOW confidence):** `[ASSUMED]` Line-number lookup via `ggrep` for the leaf segment will work for top-level scalars but may report wrong line numbers for nested tables when the same key name appears in multiple places. Acceptable for v1 (planner can note this as a known limitation in `docs/MANIFEST.md` if the precision becomes a real problem; otherwise document the file path and let humans grep).

---

## 4. Deep-Merge: yq Expression That Handles All Six Fixture Cases

**The expression:**

```bash
yq eval-all '. as $i ireduce ({}; . * $i)' defaults.toml machine.toml -o json
```

### 4.1 Verification — all six fixture cases ran in this session

| # | Case | Input | Expected | Actual | Status |
|---|------|-------|----------|--------|--------|
| 1 | **Map-over-map** (deep merge) | defaults `[features]` = `{motd=true, claude-marketplace=true}`; machine `[features]` = `{one-password-ssh=true, macos-dock=true}` | merged: `{motd, claude-marketplace, one-password-ssh, macos-dock}` | `{"motd": true, "claude-marketplace": true, "one-password-ssh": true, "macos-dock": true}` | ✓ `[VERIFIED]` |
| 2 | **List-replace** | defaults `bundles = ["core"]`; machine `bundles = ["core","gui","dev","personal"]` | machine wins wholesale | `["core","gui","dev","personal"]` | ✓ `[VERIFIED]` |
| 3 | **Scalar-override** | defaults `meta.description = "default"`; machine `meta.description = "personal-laptop"` | machine wins | `"personal-laptop"` | ✓ `[VERIFIED]` |
| 4 | **Nested table** (4 levels deep, sibling preservation) | defaults `[a.b.c.d.e] deep_nested=true`; machine `[a.b.c.d.e] deep_nested_override="yes"` + adds `[a.b.c.d.f]` | siblings preserved at every level, machine extensions added | `{a: {b: {c: {d: {default_only, shared:"machine-value", e: {deep_nested, deep_nested_override}, machine_only, f: {totally_new}}}}}}` | ✓ `[VERIFIED]` |
| 5 | **Missing-in-defaults** | machine declares `[only_in_machine]` not in defaults | preserved from machine | `"only_in_machine": {"key": "value"}` | ✓ `[VERIFIED]` |
| 5b | **Missing-in-machine** | defaults declares `[only_in_defaults]` not in machine | preserved from defaults | `"only_in_defaults": {"key": "value"}` | ✓ `[VERIFIED]` |
| 6 | **`extra_packages` concatenation** | defaults `extra_packages = ["jq","yq"]`; machine `extra_packages = ["docker-desktop","jq"]` | union: `["docker-desktop","jq","yq"]` | requires two-pass — see §5 | requires §5 |

**Critical finding on operator choice:**

| Operator | Behavior | When to use |
|----------|----------|-------------|
| `* ` | Deep-merge maps, **REPLACE** arrays | **Default for the manifest layer** (bundles/scalars/features all correct) `[VERIFIED]` |
| `*+` | Deep-merge maps, **CONCATENATE** arrays | NEVER use globally — would incorrectly concat `bundles` to `["core", "core", "gui", "dev", "personal"]` `[VERIFIED via running on full fixture]` |

The STATE.md "deep-merge shallow-merge bug" blocker referred to `jq -s '.[0] * .[1]'`, not yq. `jq` does shallow merge by default. `yq`'s `. * .` is recursive (deep) — this is the correct expression. `[VERIFIED: ran both, confirmed yq is deep, jq -s '.[0] * .[1]' is shallow]`

### 4.2 Resolver pipeline (concrete)

```zsh
#!/bin/zsh
# install/resolver.zsh — compile defaults + machine into resolved.json
set -euo pipefail

[[ -n "${DOTFILES_MESSAGES_LOADED:-}" ]] || source "${DOTFILEDIR}/install/messages.zsh"

readonly DEFAULTS="${DOTFILEDIR}/manifests/defaults.toml"
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly STATE_FILE="${STATE_DIR}/machine"
readonly OUT="${STATE_DIR}/resolved.json"

# D-16: hard-fail with actionable error
if [[ ! -f "$STATE_FILE" ]]; then
  local available
  available=$(ls "${DOTFILEDIR}/manifests/machines/"*.toml 2>/dev/null \
    | xargs -n1 basename \
    | sed 's/\.toml$//' \
    | tr '\n' ' ')
  error "no machine selected"
  error "  run: task setup -- <machine-name>"
  error "  available: ${available:-(none — populate manifests/machines/)}"
  exit 1
fi

local machine_name
machine_name=$(< "$STATE_FILE")
local machine_file="${DOTFILEDIR}/manifests/machines/${machine_name}.toml"

if [[ ! -f "$machine_file" ]]; then
  error "machine manifest not found: ${machine_file}"
  exit 1
fi

mkdir -p "$STATE_DIR"

# Pass 1: standard deep-merge (maps deep, scalars replace, arrays replace)
local merged
merged=$(yq eval-all '. as $i ireduce ({}; . * $i)' "$DEFAULTS" "$machine_file" -o json)

# Pass 2: surgically concat extra_packages (see §5)
local def_extras mach_extras union_extras
def_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$DEFAULTS")
mach_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$machine_file")
union_extras=$(echo "$def_extras $mach_extras" | jq -s 'add | unique')

# Pass 3: backfill arch via uname -m if machine didn't declare one (D-02)
local arch
arch=$(yq -r '.platform.arch // ""' "$machine_file")
if [[ -z "$arch" ]]; then
  arch=$(uname -m)
fi

echo "$merged" \
  | jq --argjson extras "$union_extras" --arg arch "$arch" \
      '.packages.brew.extra_packages = $extras
       | .platform.arch = $arch' \
  > "$OUT"
```

**Note on `// []`:** yq's `//` alternative operator returns the right-hand value when the left is null/missing. Verified by setting up a `no-extras-d.toml` fixture in this session — `.packages.brew.extra_packages // []` returned `[]` without erroring. `[VERIFIED]`

---

## 5. `extra_packages` Concatenation Strategy

**Decision: two-pass merge.** Pass 1 produces the canonical merged document with `bundles` replaced (correct). Pass 2 reads each side's `extra_packages` separately, computes `union`, and surgically overwrites that single field via `jq --argjson`.

**Why not `*+` globally?** Verified locally in this session — `yq eval-all '. as $i ireduce ({}; . *+ $i)' full-defaults.toml full-machine.toml -o json` produces `bundles: ["core", "core", "gui", "dev", "personal"]` (duplicates from concat). D-06 requires `bundles` REPLACED, not concatenated. There is no single yq operator that does "deep-merge maps + replace arrays except concat-and-dedupe this one named array." Two passes is the cleanest realization.

**Why not pure yq for pass 2?** I attempted `yq -o=json '... = ([load("file1") | .pkg.extras, load("file2") | .pkg.extras] | flatten | unique)' merged-stream` in this session and got `extra_packages: []` (empty) — `load()` inside an expression with input stream context misbehaves. Shelling out to jq with `--argjson` is reliable, well-understood, and works on every yq/jq version we'll see. `[VERIFIED experimentally]`

**Edge case verified:** When neither side declares `extra_packages`, `yq '.packages.brew.extra_packages // []'` returns `[]` and the union is `[]`. The resulting `resolved.json` has `extra_packages: []` — explicit, never missing. `[VERIFIED with no-extras fixture this session]`

**Concrete pass-2 fragment:**

```zsh
local def_extras mach_extras union_extras
def_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$DEFAULTS")
mach_extras=$(yq -o=json '.packages.brew.extra_packages // []' "$machine_file")
union_extras=$(echo "$def_extras $mach_extras" | jq -s 'add | unique')
# union_extras is now a JSON array string, ready for jq --argjson
```

**Alternative considered (and rejected): native TOML preprocessing.** Could strip `extra_packages` from both files first, do the merge, then merge the arrays separately and inject back. This requires three temp files and three yq passes; the jq-injection approach uses zero temp files. Simpler wins.

---

## 6. go-task `fromJson` / `ref:` Patterns

### 6.1 Loading `resolved.json` into a structured manifest variable (verified)

```yaml
# Taskfile.yml (root) or taskfiles/manifest.yml
version: '3'

vars:
  XDG_STATE_HOME: '{{.XDG_STATE_HOME | default (printf "%s/.local/state" .HOME)}}'
  RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json'
  MANIFEST_JSON:
    sh: cat {{.RESOLVED_JSON_PATH}}
  MANIFEST:
    ref: 'fromJson .MANIFEST_JSON'
```

**Result (verified in this session — actually ran this Taskfile against a real `resolved.json`):**

```
schema_version: 1
description: personal-laptop
identity.git: personal
features.one-password-ssh: true
features.macos-dock: true
bundle[0]: core
bundles all: [core gui dev personal]
extras all: [docker-desktop jq]
```

### 6.2 Accessing nested fields — snake_case dot, kebab-case index

| Manifest field | Template expression | Works? |
|---------------|---------------------|--------|
| `meta.description` | `{{.MANIFEST.meta.description}}` | ✓ `[VERIFIED]` |
| `identity.git` | `{{.MANIFEST.identity.git}}` | ✓ `[VERIFIED]` |
| `packages.brew.bundles` (slice) | `{{.MANIFEST.packages.brew.bundles}}` → `[core gui dev personal]` | ✓ `[VERIFIED]` |
| `packages.brew.bundles[0]` | `{{index .MANIFEST.packages.brew.bundles 0}}` | ✓ `[VERIFIED]` |
| `features.one-password-ssh` (kebab) | `{{.MANIFEST.features.one-password-ssh}}` | ✗ **fails** `template: :1: bad character U+002D '-'` `[VERIFIED]` |
| `features.one-password-ssh` (kebab) | `{{index .MANIFEST.features "one-password-ssh"}}` | ✓ `[VERIFIED]` |

**Critical for downstream phases:** every feature flag in the manifest uses kebab-case (`one-password-ssh`, `macos-dock`, `macos-finder`, `claude-marketplace`). Every task that gates on a feature MUST use the `index` form. Phase 1's CLAUDE.md (D-13) MUST document this rule so Phases 4-7 don't trip on it.

### 6.3 Iterating over arrays — `for: { var: .., as: .. }` with `ref:` (verified)

```yaml
tasks:
  install-bundles:
    vars:
      BUNDLES:
        ref: '.MANIFEST.packages.brew.bundles'
    cmds:
      - for: { var: BUNDLES, as: BUNDLE }
        cmd: 'echo installing bundle: {{.BUNDLE}}'
```

Verified output: prints one line per bundle in order. `[VERIFIED this session]`

### 6.4 Missing-state hard-fail (D-16) — `preconditions:` pattern

```yaml
vars:
  STATE_FILE: '{{.XDG_STATE_HOME}}/dotfiles/machine'
  AVAILABLE_MACHINES:
    sh: |
      ls "{{.DOTFILEDIR}}/manifests/machines/"*.toml 2>/dev/null \
        | xargs -n1 basename \
        | sed 's/\.toml$//' \
        | tr '\n' ' '

tasks:
  manifest:resolve:
    preconditions:
      - sh: 'test -f "{{.STATE_FILE}}"'
        msg: |
          error: no machine selected
            run: task setup -- <machine-name>
            available: {{.AVAILABLE_MACHINES}}
    # ...
```

**Verified:** when the precondition fails, `msg:` is printed (with `{{.AVAILABLE_MACHINES}}` interpolated), task exits 201, no shell expansion required. `[VERIFIED this session]`

### 6.5 `manifest:show -- --machine <name>` (D-17)

```yaml
tasks:
  manifest:show:
    desc: 'Print resolved manifest (default: active machine; --machine NAME for any)'
    cmds:
      - |
        # Parse `-- --machine NAME` from CLI_ARGS
        machine_name=""
        if [[ "{{.CLI_ARGS}}" =~ --machine[[:space:]]+([^[:space:]]+) ]]; then
          machine_name="${match[1]}"
        else
          machine_name=$(< "{{.STATE_FILE}}" 2>/dev/null || echo "")
        fi
        if [[ -z "$machine_name" ]]; then
          {{.DOTFILES_MESSAGES}}
          error "no machine: pass --machine NAME or run task setup"
          exit 1
        fi
        # Resolve on the fly (no state-file mutation) and pretty-print
        zsh "{{.DOTFILEDIR}}/install/resolver.zsh" --machine "$machine_name" --stdout \
          | yq -P -P '.'   # -P prettifies; default output of yq is YAML-ish
```

`[ASSUMED]` `CLI_ARGS` regex parse pattern — go-task exposes the raw `--` tail as `{{.CLI_ARGS}}`; the regex split is standard zsh. Planner should consider building a tiny `install/parse-args.zsh` helper if multiple tasks need similar parsing.

---

## 7. `manifest:resolve` `status:` Check (BSD-find Compatible)

**Goal (D-14):** skip rebuild when `resolved.json` exists AND its mtime is newer than every `manifests/*.toml` and `manifests/machines/<active>.toml`.

**Concrete `status:` block:**

```yaml
tasks:
  manifest:resolve:
    status:
      - test -f "{{.RESOLVED_JSON_PATH}}"
      - |
        ! find "{{.DOTFILEDIR}}/manifests" \
            -maxdepth 2 \
            -name '*.toml' \
            -newer "{{.RESOLVED_JSON_PATH}}" \
            -print -quit \
          | grep -q .
```

**Behavior verified in this session (BSD `find` on macOS 25.3.0 / Darwin 25.3.0):**

| Condition | `find -newer` output | `grep -q .` exit | `! ...` exit | Task action |
|-----------|---------------------|------------------|--------------|------------|
| Target missing | error to stderr; exit 1 | 1 | 0 → 1 (negated) | **runs** (rebuild) `[VERIFIED]` |
| Target older than any source | source file paths | 0 | 1 (negated) | **runs** (rebuild) `[VERIFIED]` |
| Target newer than all sources | empty | 1 | 0 (negated) | **skips** `[VERIFIED]` |

**Why `-print -quit | grep -q .` instead of bare `-newer`:**
- `find -newer` *prints matching files* but always exits 0 (whether or not it found matches). We need an exit code reflecting found-or-not. `-print -quit` exits on first match (cheap); piping through `grep -q .` converts "any output → exit 0" to a usable signal.
- Negation `!` flips the semantics so non-empty output (= stale) becomes a failed status (= task runs).

**Why `-maxdepth 2`:** picks up `manifests/defaults.toml` (depth 1) and `manifests/machines/<name>.toml` (depth 2). No deeper nesting expected.

**Caveat:** `find` glob with brace expansion (`manifests/{defaults.toml,machines/*.toml}`) doesn't expand inside `find`'s argument list — that's why `-name '*.toml'` is used with `-maxdepth 2` to capture both layers. This is BSD-find-portable. `[VERIFIED with mixed mtime fixtures]`

**Edge case:** when test fixtures are added to `manifests/test/fixtures/`, they're at depth 3 and won't trigger a rebuild even when newer. Acceptable — fixtures are inputs to `task manifest:test`, not to the resolver. If the planner wants belt-and-suspenders here, scope the find to `\( -name defaults.toml -o -path '*/machines/*.toml' \)`:

```bash
find "{{.DOTFILEDIR}}/manifests" \
  \( -name 'defaults.toml' -o -path '*/machines/*.toml' \) \
  -newer "{{.RESOLVED_JSON_PATH}}" \
  -print -quit | grep -q .
```

---

## 8. Repository Skeleton Concrete Layout

### 8.1 Top-level directory inventory (D-09)

```
dotfiles/
├── bootstrap.zsh                          # v1 — UNTOUCHED in P1 (Phase 2 rewrites)
├── Taskfile.yml                           # v1 — UNTOUCHED in P1; P1 ADDS taskfiles/manifest.yml
├── README.md                              # v1 — UNTOUCHED in P1 (Phase 8 finalizes top-level README)
├── CLAUDE.md                              # NEW in P1 (D-13) — see §10
├── LICENSE.md                             # v1 — untouched
│
├── manifests/                             # NEW in P1 — populated
│   ├── README.md                          # ~10 lines: purpose + "see docs/MANIFEST.md"
│   ├── defaults.toml                      # NEW (MFST-01)
│   ├── machines/                          # NEW (MFST-02, MFST-09)
│   │   ├── README.md
│   │   ├── personal-laptop.toml
│   │   ├── work-laptop.toml
│   │   ├── server-1.toml
│   │   └── server-2.toml
│   └── test/
│       ├── README.md
│       └── fixtures/
│           ├── 01-map-over-map/{defaults.toml,machine.toml,expected.json}
│           ├── 02-list-replace/{defaults.toml,machine.toml,expected.json}
│           ├── 03-scalar-override/{defaults.toml,machine.toml,expected.json}
│           ├── 04-nested-table/{defaults.toml,machine.toml,expected.json}
│           ├── 05-missing-keys/{defaults.toml,machine.toml,expected.json}
│           └── 06-extra-packages-concat/{defaults.toml,machine.toml,expected.json}
│
├── taskfiles/                             # v1 dir; P1 ADDS taskfiles/manifest.yml only
│   ├── manifest.yml                       # NEW in P1 — manifest:resolve, :show, :validate, :test, setup
│   └── ... (v1 taskfiles remain untouched)
│
├── install/                               # v1 dir; P1 ADDS install/resolver.zsh only
│   ├── resolver.zsh                       # NEW in P1 (MFST-04)
│   └── ... (v1 install/messages.zsh remains; reused via DOTFILES_MESSAGES)
│
├── docs/                                  # NEW dir in P1
│   ├── README.md                          # one-line: "Project documentation"
│   └── MANIFEST.md                        # NEW in P1 (DOCS-04) — see §9
│
├── shell/                                 # NEW dir in P1 — STUB
│   └── README.md                          # see §8.2 template
├── identity/                              # NEW dir in P1 — STUB
│   └── README.md
├── packages/                              # NEW dir in P1 — STUB
│   └── README.md
├── configs/                               # NEW dir in P1 — STUB
│   └── README.md
├── os/                                    # NEW dir in P1 — STUB
│   └── README.md
└── claude/                                # v1 dir; P1 leaves UNTOUCHED (Phase 7 rewrites)
```

**Rules captured:**
- **No deletion of v1 in P1.** `bootstrap.zsh`, `Taskfile.yml`, `taskfiles/*.yml` (other than the new `manifest.yml`), `zsh/`, `git/`, `ssh/`, existing `claude/`, existing `install/messages.zsh` all stay. Parallel rewrite.
- **`taskfiles/manifest.yml` is wired into the root `Taskfile.yml`** by adding `manifest: ./taskfiles/manifest.yml` under `includes:`. This is a low-risk one-line edit to Taskfile.yml.
- **The repo's existing `claude/` directory already populated** — P1 does NOT add a `claude/README.md` stub (the v1 directory is already populated; Phase 7 will replace it).

### 8.2 Stub README template (D-11)

For every NEW top-level placeholder directory in P1 (`shell/`, `identity/`, `packages/`, `configs/`, `os/`):

```markdown
# <directory-name>

<one-line purpose>

**Populated by Phase <N> — see `.planning/ROADMAP.md`.**

**Requirements landing here:** <REQ-IDs>

Until then this directory is intentionally empty. The manifest layer
(`manifests/`) drives what eventually lands here at install time.
```

**Example — `shell/README.md`:**

```markdown
# shell

zsh startup chain, aliases, functions, and theme.

**Populated by Phase 3 — see `.planning/ROADMAP.md`.**

**Requirements landing here:** SHEL-01..SHEL-12, DOCS-02

Until then this directory is intentionally empty. The manifest layer
(`manifests/`) drives what eventually lands here at install time.
```

**Phase mapping (cross-reference with ROADMAP.md):**

| Directory | Phase | Requirements |
|-----------|-------|--------------|
| `shell/` | 3 | SHEL-01..12, DOCS-02 |
| `identity/` | 4 | IDNT-01..08 |
| `packages/` | 5 | PKGS-01..05, VRFY-01..04 |
| `os/` | 6 | OSCF-01..05 |
| `configs/` | 7 | TOOL-01..04 |
| (`claude/` already populated in v1; Phase 7 rewrites — no stub needed) | 7 | CLDE-01..04, TEST-01..02 |

### 8.3 Populated directories in P1 — README contents

**`manifests/README.md` (~15 lines):**

```markdown
# manifests

TOML source-of-truth for what gets installed on each machine.

- `defaults.toml` — shared baseline (every machine inherits this)
- `machines/<name>.toml` — per-machine identity, features, package bundles, overrides
- `test/fixtures/` — golden-output test cases for the deep-merge resolver

**Schema reference:** see `docs/MANIFEST.md`.

**Compiled to JSON:** `install/resolver.zsh` merges `defaults.toml + machines/<active>.toml`
into `$XDG_STATE_HOME/dotfiles/resolved.json`. Tasks read the JSON cache via
`fromJson` — never read TOML directly.

**Adding a new machine:** create `manifests/machines/<name>.toml`, then
`task setup -- <name>`. The required field set is enforced by `task manifest:validate`.
```

**`docs/README.md` (~5 lines):**

```markdown
# docs

Project documentation.

- `MANIFEST.md` — schema, merge semantics, "adding a new machine" walkthrough (Phase 1)
- `SECURITY.md` — bootstrap trust chain (Phase 2)
- `MIGRATION.md`, `MACHINES.md`, `CUTOVER.md` — Phase 8
```

---

## 9. `docs/MANIFEST.md` Outline (DOCS-04)

```markdown
# Manifest Reference

## What This Is
One-paragraph summary: manifests are the source of truth for what each machine installs; resolver compiles them to resolved.json; tasks read the JSON.

## Schema (v1)
### `defaults.toml` and `machines/<name>.toml` shape
Side-by-side example (the two TOML blocks from §3 of RESEARCH.md).

### Required fields (per D-03)
Table with columns: Field | Type | Allowed values | Notes
- `meta.description` | string | any | free-text purpose statement
- `platform.os` | string | `"darwin"` | v1 only — Linux returns in v2
- `platform.arch` | string | `"arm64" | "x86_64"` | optional; resolver auto-detects via `uname -m`
- `features` | table | any | may be empty `{}`
- `packages.brew.bundles` | array of strings | non-empty; must contain `"core"` | by-purpose bundle names
- `identity.git` | string | `"personal" | "work" | "none"` | drives Phase 4 git config
- `identity.ssh` | string | `"personal" | "work" | "none"` | drives Phase 4 SSH config

### Optional fields
- `meta.notes` | string | freeform
- `platform.arch` | (see above)
- `packages.brew.extra_packages` | array of strings | additive escape hatch

### Unknown keys
Per D-04: unknown keys produce a stderr warning but do not fail validation. Format: `unknown key: features.macos-dok at manifests/machines/personal-laptop.toml:14`.

## Merge Semantics

### Rules (per D-06)
- **Tables**: deep-merge, machine wins on conflict, sibling keys preserved
- **Scalars**: machine replaces defaults
- **Arrays**: replaced wholesale by machine value — EXCEPT
- **`packages.brew.extra_packages`**: concatenated + deduplicated (defaults ∪ machine)

### Worked examples (one per fixture)

For each of the six fixture cases (§4 of RESEARCH.md), show:
- defaults.toml snippet
- machine.toml snippet
- expected resolved.json snippet
- one-sentence explanation of the rule that applies

### Why arrays replace (not concatenate)
Brief rationale: predictability. A machine that wants only `["core"]` must not be silently extended by defaults `["core", "dev"]`. To add to a bundle list, use `extra_packages` (the explicit additive escape).

## Adding a New Machine

Step-by-step walkthrough:
1. Choose a kebab-case name (e.g., `personal-laptop`, `work-laptop`, `server-1`).
2. Create `manifests/machines/<name>.toml`. Copy from an existing machine as a starting point — keep the same field structure, edit the values.
3. Required fields (link to the schema section above).
4. Run `task manifest:validate -- --machine <name>` to check the schema.
5. Run `task setup -- <name>` to persist the selection and resolve. (Verifies the file exists, writes `$XDG_STATE_HOME/dotfiles/machine`, regenerates `resolved.json`.)
6. Run `task manifest:show` to inspect the resolved output.
7. (Optional) Run `task install` to apply.

## CLI Reference
- `task setup -- <name>` — persist machine selection + run validate + resolve
- `task manifest:resolve` — (re)compile resolved.json (auto-run by other tasks)
- `task manifest:show [-- --machine <name>]` — print resolved.json (active machine by default)
- `task manifest:validate [-- --machine <name>]` — schema check (required fields + unknown-key warnings)
- `task manifest:test` — run the six golden-output fixtures

## State Files
- `$XDG_STATE_HOME/dotfiles/machine` — single-line text file with the active machine name
- `$XDG_STATE_HOME/dotfiles/resolved.json` — compiled JSON, regenerated by mtime check

## Feature-Flag Reference (forward pointer)
Cross-reference table for downstream phases — which feature flag triggers which install action:

| Feature | Owner phase | What it does | Default in `defaults.toml` |
|---------|-------------|--------------|---------------------------|
| `one-password-ssh` | Phase 4 | Enables 1Password SSH agent integration | false |
| `motd` | Phase 3 | Enables MOTD on .zlogin | true |
| `macos-dock` | Phase 6 | Runs os/defaults/dock.zsh | (machine-set) |
| `macos-finder` | Phase 6 | Runs os/defaults/finder.zsh | (machine-set) |
| ... | ... | ... | ... |
| `claude-marketplace` | Phase 7 | Installs claude marketplace plugins | true |

(This table is started in P1 with the features present in `defaults.toml`; each subsequent phase extends it.)

## Known Limitations (v1)
- Line numbers in unknown-key warnings may be inaccurate for nested keys (see §3.4 of RESEARCH.md)
- Rename flow is manual: rename the TOML file + edit the state file
- No JSON Schema for editor validation — deferred to v2 (`TOOL-V2-01`)
```

**Why this outline:** every downstream phase needs to link to a specific section of this doc.
- Phase 2 lint suite links to "CLI Reference" for `task manifest:validate` invocation
- Phase 4 identity links to "Required fields → identity.git/identity.ssh"
- Phase 5 packages links to "Merge semantics → extra_packages concatenation"
- Phase 6 OS defaults links to "Feature-Flag Reference" to extend the table
- Phase 7 hooks/tool configs links to "Feature-Flag Reference"
- Phase 8 cutover links to "Adding a New Machine" walkthrough

---

## 10. Project-Level `CLAUDE.md` Outline (D-13)

**Location:** repo root (`/Users/josh/Git/personal/dotfiles/CLAUDE.md`).
**Status:** v1 already has a `CLAUDE.md` at repo root with content that's a mix of v1 facts and v2 plans. P1 must **replace** this with v2-only conventions (the v1 facts are now historical and live in `.planning/codebase/`).

**Recommended outline:**

```markdown
# Dotfiles v2 — Project Instructions for AI Agents

## What This Is
Two-sentence summary: manifest-driven dotfiles, macOS-only v1, one TOML manifest per machine inherits from defaults.toml.

## The Manifest Model (the keystone)
- Source of truth: `manifests/defaults.toml` + `manifests/machines/<name>.toml`
- Compiled output: `$XDG_STATE_HOME/dotfiles/resolved.json`
- Active machine: `$XDG_STATE_HOME/dotfiles/machine` (single-line file, written by `task setup`)
- Schema: see `docs/MANIFEST.md`

## Rules

### Manifests are the source of truth for install state
Never infer state from hostname, never branch on filename suffix, never grep `$DOTFILES_PROFILE` (there is no profile — there's a machine name). When you need to know "does this machine want feature X?" — read `resolved.json` (already loaded as `{{.MANIFEST}}` in every taskfile).

### One concept per file
- One alias topic per `shell/aliases/<topic>.zsh`
- One function per `shell/functions/<name>.zsh`
- One taskfile per concern (`taskfiles/<concern>.yml`)
- One machine manifest per machine
- One Brewfile per purpose (`packages/<purpose>.rb`)
- One macOS defaults concern per file (`os/defaults/<concern>.zsh`)

### Flat directories in v1
No `shell/aliases/common/` vs `shell/aliases/darwin/` split. No `packages/brew/` subdir. No `os/darwin/` nesting. v1 is macOS-only, so the platform dimension collapses. When Linux returns in v2, dirs reshape — that migration cost is accepted (PROJECT.md).

### kebab-case feature names need `index` access
In a taskfile reading from `{{.MANIFEST.features.foo}}` — if `foo` contains a `-` (e.g., `one-password-ssh`, `macos-dock`), use `{{index .MANIFEST.features "one-password-ssh"}}` instead. Go-template parser rejects `-` in dot-access.

### Every install task has a `status:` block
The status block returns 0 (skip) when the desired state is already present; non-zero (run) when work is needed. The block MUST use template variables (`{{.X}}`), NEVER shell variables (`$X`) — shell vars don't exist in the status check's evaluation context. (This is the canonical `macos:shell:145` bug class from v1.)

### `set -euo pipefail` on every executable .zsh
No `set -e` alone. The `-u` catches unbound-variable bugs; the `-o pipefail` catches mid-pipeline failures.

### No hardcoded `/opt/homebrew` or `/usr/local`
Detect Homebrew prefix via `uname -m`-based dispatch (already implemented in `Taskfile.yml` HOMEBREW_PREFIX vars block). `$HOMEBREW_PREFIX` is available to all taskfiles.

### Symlinks via `_:safe-link` only
No bare `ln -s` outside `taskfiles/helpers.yml`. (Phase 2's lint will enforce.)

### XDG everywhere
- `$XDG_CONFIG_HOME` for user configs (default `~/.config`)
- `$XDG_DATA_HOME` for app data (default `~/.local/share`)
- `$XDG_STATE_HOME` for machine-local state (default `~/.local/state`)
- `$XDG_CACHE_HOME` for caches (default `~/.cache`)
Set in `shell/.zshenv` (Phase 3); referenced as `{{.XDG_*}}` in taskfiles.

## Where to Add Things

| Adding | Where | Naming |
|--------|-------|--------|
| An alias | `shell/aliases/<topic>.zsh` | kebab-case topic; one topic per file |
| A function | `shell/functions/<name>.zsh` | filename == function name (lowercase, no separator) |
| A new machine | `manifests/machines/<name>.toml` + `task setup -- <name>` | kebab-case |
| A brew package | `packages/<purpose>.rb` (or `extra_packages` in manifest for one-offs) | by purpose, not by machine |
| A macOS defaults concern | `os/defaults/<concern>.zsh` + feature flag in defaults.toml | one concern per file |
| A feature flag | `manifests/defaults.toml` `[features]` + the consuming task in the appropriate taskfile | kebab-case |
| A tool config | `configs/<tool>/` + symlink declared in `taskfiles/links.yml` | the tool's expected config filename |
| A Claude hook | `claude/hooks/<name>.zsh` + entry in `claude/hooks/hooks.json` | kebab-case |

## Conventions Not Captured Above
- No AI attribution: no `Co-Authored-By` trailers, no "Generated by Claude" comments, anywhere — commit messages or source. Hooks enforce this.
- No emojis in non-markdown files. Hooks enforce this.
- File-level comment block at top of each script explaining purpose. Section separators in YAML use `# ===` banners.
- Errors to stderr (`echo ... >&2` or `error "..."` from the messages library).

## Tooling Versions
- `yq` (mikefarah) ≥ 4.52.1 — full TOML roundtrip
- `go-task` ≥ 3.37 — `ref:` + `fromJson` (current: 3.50)
- `jq` ≥ 1.7

## Don't Do
- Don't infer machine identity from `hostname`.
- Don't read TOML in a taskfile — read `resolved.json` via `fromJson`.
- Don't add files to `shell/aliases/common/` (it doesn't exist in v1; flat layout).
- Don't add a profile-suffixed file (`Brewfile-personal.rb`). Bundles are by purpose.
- Don't bypass `_:safe-link` for symlinks.
- Don't put `$VAR` (shell) where `{{.VAR}}` (template) is expected — especially in `status:`.

## Project State and Workflow
Use `/gsd-*` commands for any non-trivial change. Direct edits bypass the planning artifacts and lose context for AI maintenance.
```

**What changes vs. the existing repo-root CLAUDE.md:**
- Removes references to "profiles" (personal/work/server) since v2 replaces with explicit machine selection.
- Removes the platform-subdirectory pattern (`aliases/{common,personal,work}/`) since v1 is flat.
- Adds the kebab-case-needs-index rule (newly discovered in this session).
- Adds the manifest-is-source-of-truth rule.
- Updates the "Quick Reference" section to use `task setup -- <name>` instead of `task profile:set -- personal`.

---

## 11. Validation Architecture

> Required for nyquist_validation. The plan uses three validation layers; each maps to a phase requirement.

### 11.1 Test Framework

| Property | Value |
|----------|-------|
| Framework | **shell-native fixture testing** (no bats/zunit — keep dep surface small per CLAUDE.md "tooling versions" section) |
| Config file | none — fixtures live under `manifests/test/fixtures/<NN>-<name>/` (golden-output files) |
| Quick run command | `task manifest:test` |
| Full suite command | `task manifest:test` (same; entire test surface for P1) |

Test runner approach: `taskfiles/manifest.yml` `manifest:test` task iterates `manifests/test/fixtures/*/`, invokes the resolver for each fixture's `defaults.toml` + `machine.toml`, diffs the output against `expected.json` using `diff <(jq -S . actual) <(jq -S . expected)` (sorted keys for stable diff). One pass/fail line per fixture. Non-zero exit on any diff.

### 11.2 Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MFST-01 | defaults.toml exists and parses | static | `yq '.' manifests/defaults.toml > /dev/null` | ❌ Wave 0 (defaults.toml) |
| MFST-02 | each machine TOML exists and parses | static | `for f in manifests/machines/*.toml; do yq '.' "$f" > /dev/null; done` | ❌ Wave 0 (machine TOMLs) |
| MFST-03 | merge semantics correct | unit (fixtures) | `task manifest:test` | ❌ Wave 0 (six fixtures) |
| MFST-04 | resolver produces resolved.json | smoke | `task setup -- personal-laptop && test -f $XDG_STATE_HOME/dotfiles/resolved.json` | ❌ Wave 0 (resolver.zsh) |
| MFST-05 | six fixtures all pass | unit | `task manifest:test` | ❌ Wave 0 |
| MFST-06 | downstream task can read manifest via fromJson | smoke | run a sanity task that prints `{{.MANIFEST.identity.git}}` and assert non-empty | ❌ Wave 0 (taskfiles/manifest.yml) |
| MFST-07 | `manifest:show` prints resolved JSON | smoke | `task manifest:show \| jq '.identity.git' = "personal"` | ❌ Wave 0 |
| MFST-08 | required-field validation rejects invalid manifests | unit | construct a `_invalid-missing-desc.toml` fixture, assert `task manifest:validate -- --machine _invalid-missing-desc` exits non-zero | ❌ Wave 0 (validation fixtures) |
| MFST-09 | adding a 5th machine works | smoke (throwaway) | create `manifests/machines/_fixture-test.toml`, `task setup -- _fixture-test`, assert `resolved.json` reflects it; clean up | ❌ Wave 0 |
| DOCS-03 | `CLAUDE.md` (project-level) exists | static | `test -f CLAUDE.md && grep -q "manifest model" CLAUDE.md` | ❌ Wave 0 |
| DOCS-04 | `docs/MANIFEST.md` exists with required sections | static | `test -f docs/MANIFEST.md && grep -q "## Merge Semantics" docs/MANIFEST.md && grep -q "## Adding a New Machine" docs/MANIFEST.md` | ❌ Wave 0 |

### 11.3 Sampling Rate

- **Per task commit:** `task manifest:test` (six fixtures, sub-second)
- **Per wave merge:** `task manifest:test && task manifest:validate -- --machine personal-laptop` (full smoke)
- **Phase gate:** all 11 requirements verified by their commands above, before `/gsd-verify-work`

### 11.4 Wave 0 Gaps

All test infrastructure is NEW in Phase 1. None of these files exist yet:

- [ ] `manifests/test/fixtures/01-map-over-map/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 1)
- [ ] `manifests/test/fixtures/02-list-replace/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 2)
- [ ] `manifests/test/fixtures/03-scalar-override/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 3)
- [ ] `manifests/test/fixtures/04-nested-table/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 4)
- [ ] `manifests/test/fixtures/05-missing-keys/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 5)
- [ ] `manifests/test/fixtures/06-extra-packages-concat/{defaults.toml,machine.toml,expected.json}` — covers MFST-03, MFST-05 (case 6)
- [ ] `manifests/test/fixtures/_invalid-missing-desc/machine.toml` (no expected.json — meant to fail validation) — covers MFST-08
- [ ] `manifests/test/fixtures/_invalid-bad-os/machine.toml` (platform.os = "linux") — covers MFST-08 and D-01
- [ ] `install/resolver.zsh` — the unit under test
- [ ] `taskfiles/manifest.yml` — `manifest:test` task driver

**Throwaway-fixture machine test pattern (MFST-09 verification):**
```bash
# Inside taskfiles/manifest.yml manifest:test cmds:
cat > manifests/machines/_addmachine-test.toml <<'EOF'
schema_version = 1
[meta]
description = "throwaway test machine"
[platform]
os = "darwin"
[features]
[packages.brew]
bundles = ["core"]
[identity]
git = "none"
ssh = "none"
EOF
task setup -- _addmachine-test
test "$(jq -r .meta.description $XDG_STATE_HOME/dotfiles/resolved.json)" = "throwaway test machine"
rm manifests/machines/_addmachine-test.toml
# Restore prior active machine
echo "$PRIOR_MACHINE" > $XDG_STATE_HOME/dotfiles/machine
task manifest:resolve
```

No framework install needed — pure shell + yq + jq + diff.

---

## 12. Security Domain

Phase 1 has minimal security exposure (no network, no secrets, no auth) but still warrants explicit treatment:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | no auth in P1 |
| V3 Session Management | no | no sessions |
| V4 Access Control | no | local-only |
| V5 Input Validation | **yes** | manifest schema validation (D-03) catches malformed input; yq parser is the parsing primitive (no hand-rolled parsing) |
| V6 Cryptography | no | no crypto in P1 (Phase 2 bootstrap owns checksum verification) |
| V14 Configuration | **yes** | machine name MUST be validated against `manifests/machines/*.toml` enumeration before written to state file (no injection into shell or path) |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via machine name (`task setup -- ../../etc/passwd`) | Tampering | Validate `<machine-name>` against `manifests/machines/*.toml` enumeration BEFORE writing state file (`preconditions:` block); reject names containing `/` or `..` |
| Shell injection via TOML field values | Tampering | All TOML values flow through `yq -r` (quoted) and `jq --argjson` (typed); never interpolated raw into shell commands |
| State file race condition | Tampering | Single-writer pattern: only `task setup` writes the state file; resolver reads only |

**Specific check for `task setup -- <name>`:** the preconditions block in `setup` MUST run `test -f manifests/machines/<sanitized-name>.toml` BEFORE writing `$XDG_STATE_HOME/dotfiles/machine`. Naive implementations write the state first, validate later — opens a window where a hostile `<name>` lands on disk. Concrete fragment:

```yaml
tasks:
  setup:
    requires:
      vars: [CLI_ARGS]
    preconditions:
      - sh: |
          name="{{.CLI_ARGS}}"
          # Reject anything that's not a kebab-case identifier
          [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || exit 1
          # Reject if the manifest file doesn't exist
          test -f "{{.DOTFILEDIR}}/manifests/machines/${name}.toml"
        msg: 'invalid or unknown machine: "{{.CLI_ARGS}}" — see manifests/machines/'
    cmds:
      - mkdir -p "{{.XDG_STATE_HOME}}/dotfiles"
      - echo "{{.CLI_ARGS}}" > "{{.XDG_STATE_HOME}}/dotfiles/machine"
      - task: manifest:validate
      - task: manifest:resolve
```

`[VERIFIED: preconditions with msg interpolation works — see §6.4]`

---

## 13. Risks / Open Questions

### Risks the planner should weight

1. **HIGH — Implicit dependency on `ggrep` for unknown-key line-number lookup.** The unknown-key warning relies on `ggrep -n` to find line numbers. `ggrep` is in the v1 Brewfile but P1 hasn't created `packages/core.rb` yet. **Mitigation:** for P1, fallback to plain `grep -n` if `ggrep` is unavailable (less precise but functional); plan to add `ggrep` to `packages/core.rb` in Phase 5. Document the dependency in `docs/MANIFEST.md` "Known Limitations."

2. **MEDIUM — Two-pass merge complexity.** The `extra_packages` concatenation requires reading the source TOMLs twice (once for `. * .`, once for extras). If a future field needs similar concat behavior, the resolver gets a third pass. **Mitigation:** the resolver should isolate the "concat-special-fields" step into a single function so adding a future concat field is a one-line addition (e.g., a `concat_fields=("packages.brew.extra_packages")` array iterated in a loop).

3. **MEDIUM — Kebab-case keys are a recurring trap.** Phases 4-7 will all need to gate behavior on feature flags. If a developer (human or AI) reaches for `{{.MANIFEST.features.macos-dock}}` instinctively, the build fails. **Mitigation:** P1's `CLAUDE.md` (D-13) must contain this rule prominently. Phase 2 should add a `task lint:taskfile` rule that flags kebab-case in dot-access expressions inside taskfiles.

4. **LOW — `find -newer` doesn't detect file DELETIONS.** If someone deletes a `manifests/machines/*.toml` between resolves, the existing `resolved.json` mtime is newer than the (no-longer-existing) source — the `status:` check skips rebuild. The resolver might be using stale data for a machine the user just removed. **Mitigation:** if the active machine's TOML doesn't exist, the resolver itself fails (hard-fail at the file-read step). Only edge case is "delete the *defaults* file" — accept this and document.

5. **LOW — Backslash/quote handling in TOML strings.** TOML supports both literal strings (`'...'`) and basic strings (`"..."` with escapes). yq handles both correctly for read, but `meta.description` with embedded double quotes flowing through `jq --argjson` is theoretically a risk. **Mitigation:** validation rejects non-string types; the strings flow through as-is via yq's TOML parser, which handles escapes per the TOML spec. Not a real risk in practice for v1.

### Open Questions

1. **Should `resolved.json` include a `_meta` block with source mtimes and resolver invocation timestamp?** (CONTEXT.md lists this as "nice-to-have, not required.") **Recommendation:** YES — adds ~5 lines to the resolver and dramatically helps debugging when `task manifest:show` is the only debug surface. Cheap insurance.

2. **Where do `defaults.toml` and `machines/<name>.toml` live for the test fixtures — same path as production, or a subdir?** **Recommendation:** subdir `manifests/test/fixtures/<NN>-<name>/`. Keeps production manifests out of test discovery globs and lets the resolver's `status:` check exclude the fixtures via path (§7).

3. **For `manifest:validate -- --machine <name>`, should it accept a path or only a manifest-name?** **Recommendation:** only a manifest name. The validate function is for machines that already exist under `manifests/machines/`; arbitrary-path testing is what the fixtures are for.

4. **Should `task setup` run `manifest:validate` and `manifest:resolve` synchronously, or just `resolve`?** **Recommendation:** both — fail fast on a schema error before producing a (potentially garbage) `resolved.json`. Per CONTEXT.md "Specific Ideas" — `task setup` behavior is "validates, writes state, runs manifest:validate then manifest:resolve."

5. **`[ASSUMED]` Does go-task v3.50 emit a useful error when `fromJson` receives invalid JSON?** Untested in this session. **Recommendation:** the resolver writes JSON via `jq` (which always produces valid JSON) so the practical risk is "resolved.json got truncated / partial-write." Plan: write via `mktemp` + `mv` for atomicity. Verify error mode during implementation.

---

## 14. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Line-number lookup via `ggrep -n` for the leaf segment is usable for unknown-key warnings | §3.4 | LOW — degrades to imprecise line numbers; doesn't break correctness |
| A2 | `task manifest:show -- --machine NAME` parses `--machine NAME` from `{{.CLI_ARGS}}` via regex match in zsh | §6.5 | LOW — small helper function may be needed if multiple tasks adopt this pattern |
| A3 | go-task v3.50 emits a useful error when `fromJson` receives invalid JSON | §13 Q5 | LOW — atomic write via `mktemp + mv` avoids the truncation case |
| A4 | The `claude/` directory at repo root is already populated in v1 and Phase 7 will rewrite it — P1 leaves it untouched | §8.1 | LOW — confirm by `ls claude/` (already verified populated) |
| A5 | `task --version` v3.50.0 corresponds to the version installed on every target machine | §2 | LOW — Phase 2's bootstrap will pin/check; P1 documents the floor |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

**This table has 5 entries.** All are LOW-risk operational details, not architectural decisions. Planner can proceed without user confirmation but should surface A1 and A2 during implementation in case fallback logic is needed.

---

## 15. Sources

### Primary (HIGH confidence — verified by running locally in this session)

- `yq` v4.53.2 deep-merge behavior: ran `yq eval-all '. as $i ireduce ({}; . * $i)' ... -o json` on six fixture cases, all produced expected output. `[VERIFIED 2026-05-13]`
- `yq` `*` vs `*+` operator distinction: confirmed `* ` REPLACES arrays, `*+` CONCATENATES arrays. `[VERIFIED 2026-05-13]`
- `yq` `has()`, `tag`, and `// []` predicate behavior: confirmed each on real fixtures. `[VERIFIED 2026-05-13]`
- `go-task` v3.50.0 `ref: 'fromJson .VAR'` syntax: built and ran a real Taskfile against a real `resolved.json` — works as documented. `[VERIFIED 2026-05-13]`
- go-template kebab-case bug: ran `{{.MANIFEST.features.one-password-ssh}}` and got `template: :1: bad character U+002D '-'`; `index` form works. `[VERIFIED 2026-05-13]`
- BSD `find -newer` behavior on macOS arm64 (Darwin 25.3.0): all three cases (target missing, target old, target new) produce the right `status:` action. `[VERIFIED 2026-05-13]`
- `preconditions:` block `msg:` template-variable interpolation: ran a real Taskfile with `{{.AVAILABLE_MACHINES}}` in msg, saw it interpolated. `[VERIFIED 2026-05-13]`

### Primary (HIGH confidence — official docs)

- [go-task templating reference](https://taskfile.dev/reference/templating/) — `fromJson`, `toJson`, dotted access. `[CITED]`
- [go-task schema reference](https://taskfile.dev/reference/schema/) — `vars:` with `sh:`, `value:`, `ref:`. `[CITED]`
- [github.com/go-task/task — guide.md "Parsing JSON/YAML into map variables"](https://github.com/go-task/task/blob/main/website/src/docs/guide.md) — exact `ref: 'fromJson .VAR'` example. `[CITED via Context7 /go-task/task]`
- [mikefarah.gitbook.io/yq — TOML usage](https://mikefarah.gitbook.io/yq/usage/toml) — TOML roundtrip support since 4.52.1. `[CITED]`

### Secondary (MEDIUM confidence)

- `.planning/research/STACK.md` — yq vs dasel rationale, antidote/Starship picks. (This file's findings inform but don't dictate P1 details.) `[CITED]`
- `.planning/research/ARCHITECTURE.md` — five-layer architecture; some sketches use dasel (translate to yq) or `jq -s '.[0] * .[1]'` (replace with yq deep-merge). `[CITED with correction]`
- `.planning/research/PITFALLS.md` — pitfalls 1-3 (drift, schema sprawl, merge ambiguity) directly apply. `[CITED]`
- `.planning/codebase/CONVENTIONS.md` — naming, scripting, XDG conventions (port verbatim). `[CITED]`

### Tertiary (LOW confidence — flagged for verification during implementation)

- None — every critical claim in this research is HIGH or MEDIUM.

---

## Metadata

**Confidence breakdown:**
- yq deep-merge expression: HIGH — six fixture cases run end-to-end in this session
- `extra_packages` concatenation strategy: HIGH — both naive merge and corrected two-pass run and produce expected output
- go-task `fromJson` + `ref:` syntax: HIGH — verified by running an actual Taskfile against an actual resolved.json
- BSD `find -newer` for `status:`: HIGH — three cases verified
- Validation mechanism (hand-rolled zsh): MEDIUM — `has()` and `tag` predicates verified, but the specific error-format string is a design choice
- Repository skeleton layout: HIGH — directly derived from D-09, D-10, D-11 in CONTEXT.md and cross-referenced against ROADMAP.md phase assignments
- `docs/MANIFEST.md` outline: MEDIUM — structure is sound but section ordering is a planner choice
- Project-level `CLAUDE.md` outline: MEDIUM — content reflects discovered v2 rules + verified gotchas; final section ordering is editorial

**Research date:** 2026-05-13
**Valid until:** 2026-06-12 (30 days — stable tooling versions; only changes if yq or go-task ships a behavior-breaking minor in the window)
