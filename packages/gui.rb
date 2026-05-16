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
# Verify is data-driven from `brew info` post-Gap-2 pivot; see
# ../docs/MANIFEST.md `## Verify model`.
#
# Conventions:
#   - Single-quote string-literal form.
#   - No per-line verify annotations required -- the verify task reads
#     artifact paths directly from `brew info --installed --json=v2`.
#   - Beyond the two lines below, GUI apps live in per-machine
#     `manifests/machines/<name>.toml` `[packages.brew.extra_packages.casks]`
#     -- per D-02 minimal-bundles philosophy (Plan 02 migrations).
#   - The 1Password command-line tool is NOT here -- it lives in core.rb as a
#     binary-only cask (`cask '1password-cli'`; no /Applications/.app bundle).

cask '1password'
cask 'ghostty'
