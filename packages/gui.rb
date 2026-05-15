# packages/gui.rb -- laptop GUI baseline. Any machine with a display.
#
# Purpose:     The minimum GUI app set for v2 laptops (servers do NOT include
#              this bundle). Sourced verbatim by the composer
#              (taskfiles/packages.yml, install/compose-brewfile.zsh) and
#              concatenated into the per-machine composed Brewfile at
#              $XDG_CACHE_HOME/dotfiles/Brewfile when the active machine's
#              `packages.brew.bundles` array contains "gui".
# Side effects: None at source time -- this is static Ruby DSL content read by
#              `brew bundle install` against the composed Brewfile.
#
# Verify rules (consumed by `task packages:verify` in Plan 04):
#   cask '<name>' # verify: <App Name>  -> /Applications/<App Name>.app  (MANDATORY per D-04)
#
# Conventions:
#   - Single-quote string-literal form.
#   - Cask `# verify: <App>` is MANDATORY on every line; no derivation, no
#     defaults. Cask app names diverge from cask names enough that any
#     derivation heuristic produces enough false-negatives to undermine the
#     verify contract (D-04). LINT-09 (Plan 04) rejects any cask line without
#     `# verify:`.
#   - Beyond the two lines below, GUI apps live in per-machine
#     `manifests/machines/<name>.toml` `[packages.brew.extra_packages.casks]`
#     -- per D-02 minimal-bundles philosophy (Plan 02 migrations).
#   - The 1Password command-line tool is NOT here -- it lives in core.rb as a
#     formula-style entry with `# verify: op` (uniform formula-line verify;
#     the corresponding Homebrew cask has no .app bundle).

cask '1password' # verify: 1Password
cask 'ghostty' # verify: Ghostty
