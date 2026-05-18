# packages/core.rb -- server-safe CLI baseline. Every machine includes this.
#
# Purpose:     CLI tools required on every v2 machine (laptops and servers).
#              Sourced verbatim by the composer (taskfiles/packages.yml,
#              install/compose-brewfile.zsh) and concatenated into the
#              per-machine composed Brewfile at $XDG_CACHE_HOME/dotfiles/Brewfile.
# Side effects: None at source time -- this is static Ruby DSL content read by
#              `brew bundle install` against the composed Brewfile.
#
# Verify is data-driven from `brew info` post-Gap-2 pivot; see
# ../docs/MANIFEST.md `## Verify model` for the canonical model and
# ../packages/README.md `## Verify rules` for the user-facing summary.
#
# Conventions:
#   - Single-quote string-literal form.
#   - No per-line verify annotations required -- the verify task reads
#     artifact paths directly from `brew info --installed --json=v2`.
#   - No global brew-bundle args directives here -- core.rb has no casks; any
#     downstream cask lines (gui.rb + per-machine extras) inherit brew bundle's
#     default appdir (/Applications).
#
# Notable surgery vs v1 install/Brewfile.rb:
#   - Carries forward `brew 'antigen'` from v1 (v2 reverted Phase 3 D-01's
#     antidote experiment because antidote's static-bundle did not replicate
#     antigen's `antigen use ohmyzsh/ohmyzsh` lib-loading; the prompt and
#     several OMZ helpers broke without it).
#   - Adds  `cask '1password-cli'` (binary-only cask: Homebrew lists this as a
#                                   cask that ships the `op` binary to
#                                   /opt/homebrew/bin -- no /Applications/.app
#                                   bundle; gap-1 fix preserved, bin: verify
#                                   convention retired by gap-2 pivot).

brew 'zsh'
brew 'go-task'
brew 'yq'
brew 'jq'
brew 'git'
brew 'git-delta'
brew 'node'
brew 'openssh'
brew 'wget'
brew 'eza'
brew 'bat'
brew 'fd'
brew 'grep'
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
brew 'trippy'
brew 'cloudflared'
brew 'fastfetch'
brew 'onefetch'
brew 'bottom'
brew 'coreutils'
brew 'mas'
brew 'antigen'
cask '1password-cli'
