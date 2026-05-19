---
phase: 14
slug: comment-doc-trim
artifact: METRICS
created: 2026-05-18
pre_snapshot_at: 2026-05-18
post_snapshot_at: pending
---

# Phase 14 -- Comment-to-Code Metrics

Comment-to-code ratio measurements per file for Phase 14 TRIM-01 evidence.
Pre-snapshot taken before any Plan 14-02 trim commit; post-snapshot taken at
Plan 14-02 close. Methodology: `grep -cE '^[[:space:]]*#'` for comments;
`grep -cvE '^[[:space:]]*(#|$)'` for code; right-aligned numeric columns.

Note on file paths: PLAN.md lists `install/bootstrap.zsh`; the actual file
lives at the repo root as `bootstrap.zsh` (deviation Rule 3 -- path correction).

| file                                            | code_lines | comments_pre | comments_post | delta | % reduction |
|-------------------------------------------------|-----------:|-------------:|--------------:|------:|------------:|
| taskfiles/links.yml                             |        334 |          230 |            80 |  -150 |         65% |
| shell/.zlogout                                  |          1 |           53 |             9 |   -44 |         83% |
| Taskfile.yml                                    |        132 |          102 |            67 |   -35 |         34% |
| taskfiles/packages.yml                          |        294 |          202 |            78 |  -124 |         61% |
| taskfiles/identity.yml                          |        272 |          167 |            76 |   -91 |         54% |
| taskfiles/lint.yml                              |        258 |          142 |            64 |   -78 |         54% |
| taskfiles/claude.yml                            |        180 |          141 |            48 |   -93 |         65% |
| taskfiles/macos.yml                             |        170 |          130 |            45 |   -85 |         65% |
| taskfiles/manifest.yml                          |        146 |          122 |            49 |   -73 |         59% |
| taskfiles/test.yml                              |        190 |          108 |            54 |   -54 |         50% |
| taskfiles/shell.yml                             |         73 |           68 |            19 |   -49 |         72% |
| taskfiles/helpers.yml                           |         68 |           27 |             9 |   -18 |         66% |
| taskfiles/audit.yml                             |         23 |           14 |            12 |    -2 |         14% |
| taskfiles/show.yml                              |         16 |           12 |            11 |    -1 |          8% |
| taskfiles/refresh.yml                           |         10 |           11 |            10 |    -1 |          9% |
| install/resolver.zsh                            |        392 |          183 |           110 |   -73 |         39% |
| install/messages.zsh                            |         37 |           30 |            15 |   -15 |         50% |
| bootstrap.zsh                                   |         54 |           51 |           TBD |   TBD |         TBD |
| install/compose-brewfile.zsh                    |        100 |          101 |           TBD |   TBD |         TBD |
| install/test-hooks.zsh                          |         93 |           70 |           TBD |   TBD |         TBD |
| os/defaults/dock.zsh                            |         18 |           37 |           TBD |   TBD |         TBD |
| os/defaults/finder.zsh                          |         15 |           41 |           TBD |   TBD |         TBD |
| os/defaults/input.zsh                           |         13 |           42 |           TBD |   TBD |         TBD |
| os/defaults/screenshots.zsh                     |         16 |           54 |           TBD |   TBD |         TBD |
| os/defaults/security.zsh                        |         48 |           92 |           TBD |   TBD |         TBD |
| os/shell-registration.zsh                       |         34 |           60 |           TBD |   TBD |         TBD |
| identity/ssh/cloudflared.zsh                    |         16 |           15 |           TBD |   TBD |         TBD |
| shell/.zshenv                                   |         25 |           47 |           TBD |   TBD |         TBD |
| shell/.zprofile                                 |         17 |           46 |           TBD |   TBD |         TBD |
| shell/.zshrc                                    |         63 |           71 |           TBD |   TBD |         TBD |
| shell/.zlogin                                   |          3 |           15 |           TBD |   TBD |         TBD |
| shell/theme.zsh                                 |         56 |           26 |           TBD |   TBD |         TBD |
| claude/hooks/lib.zsh                            |         40 |           35 |           TBD |   TBD |         TBD |
| claude/hooks/secret-scan.zsh                    |         13 |            5 |           TBD |   TBD |         TBD |
| claude/hooks/no-emojis.zsh                      |         12 |            6 |           TBD |   TBD |         TBD |
| claude/hooks/no-ai-comments.zsh                 |         15 |            4 |           TBD |   TBD |         TBD |
| claude/hooks/agent-transparency.zsh             |         31 |            8 |           TBD |   TBD |         TBD |
| shell/functions/_dotfiles_feature.zsh           |         15 |           26 |           TBD |   TBD |         TBD |
| shell/functions/_dotfiles_require_feature.zsh   |          7 |           34 |           TBD |   TBD |         TBD |
| shell/aliases/jgrid.zsh                         |         30 |           20 |           TBD |   TBD |         TBD |
| shell/aliases/ghostty.zsh                       |          4 |           13 |           TBD |   TBD |         TBD |
| shell/aliases/finder.zsh                        |         12 |           11 |           TBD |   TBD |         TBD |
| shell/aliases/dotfiles.zsh                      |          1 |            9 |           TBD |   TBD |         TBD |
| **Total**                                       |  **3,347** |    **2,681** |       **TBD** | **TBD** |     **TBD** |
