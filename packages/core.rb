# packages/core.rb -- server-safe CLI baseline. Every machine includes this.
#
# Purpose:     CLI tools required on every v2 machine (laptops and servers).
#              Sourced verbatim by the composer (taskfiles/packages.yml,
#              install/compose-brewfile.zsh) and concatenated into the
#              per-machine composed Brewfile at $XDG_CACHE_HOME/dotfiles/Brewfile.
# Side effects: None at source time -- this is static Ruby DSL content read by
#              `brew bundle install` against the composed Brewfile.
#
# Verify rules (consumed by `task packages:verify` in Plan 04):
#   brew '<name>'                  -> command -v <name>     (default; D-05)
#   brew '<name>' # verify: <bin>  -> command -v <bin>      (override; D-05)
#
# Conventions:
#   - Single-quote string-literal form.
#   - Override comments use the exact shape `# verify: <bin>` (single space
#     after `#`, single space after `:`); the verify parser in Plan 04 is
#     anchored on that shape.
#   - No global brew-bundle args directives here -- core.rb has no casks; any
#     downstream cask lines (gui.rb + per-machine extras) inherit brew bundle's
#     default appdir (/Applications).
#
# Notable surgery vs v1 install/Brewfile.rb:
#   - Drops the v1 zsh plugin manager line (Phase 3 swapped it for antidote).
#   - Adds  `brew 'antidote'`    (the v2 plugin manager wired in Phase 3).
#   - Adds  `brew '1password-cli' # verify: op` (CLI-only cask with no .app
#                                  bundle; expressed formula-style so the
#                                  verify rule stays uniform -- Claude's
#                                  Discretion call in 05-CONTEXT.md).
#   - Adds  `# verify: <bin>` overrides on the multi-binary / renamed-binary
#     formulas: git-delta -> delta, grep -> ggrep, openssh -> ssh,
#     trippy -> trip, bottom -> btm, coreutils -> gsha256sum.

brew 'zsh'
brew 'go-task'
brew 'yq'
brew 'jq'
brew 'git'
brew 'git-delta'           # verify: delta
brew 'openssh'             # verify: ssh
brew 'wget'
brew 'eza'
brew 'bat'
brew 'fd'
brew 'grep'                # verify: ggrep
brew 'glow'
brew 'highlight'
brew 'grc'
brew 'htop'
brew 'duf'
brew 'whois'
brew 'doggo'
brew 'hugo'
brew 'ncdu'
brew 'tlrc'
brew 'trippy'              # verify: trip
brew 'cloudflared'
brew 'fastfetch'
brew 'onefetch'
brew 'bottom'              # verify: btm
brew 'coreutils'           # verify: gsha256sum
brew 'mas'
brew '1password-cli'       # verify: op
brew 'antidote'
