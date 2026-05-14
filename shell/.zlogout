#!/bin/zsh
# -----------------------------------------------------------------------------
# .zlogout - Zsh login-shell logout hook
#
# Sourced by: login shells when they exit (read only for login shells).
# Logout lifecycle position (for a login interactive shell):
#   1) ~/.zshrc         (interactive setup)
#   2) ~/.zlogin        (after .zshrc for login shells)
#   - When the login shell exits, Zsh will source this file:
#   - ~/.zlogout is read when a login shell exits
#
# Purpose:
#   - Provide a place for finalization and cleanup tasks that should run when
#     a login shell exits. Examples: flush history, remove per-session temp
#     files, shut down session-only helpers (ssh-agent started by login, tunnels
#     started for the session), lock credential helpers, or perform light
#     logging/notifications.
#
# Typical safe contents / examples:
#   - Ensure history is flushed to disk:
#       fc -W
#   - Clear the visible terminal only for top-level login shells:
#       if [[ "$SHLVL" = 1 ]]; then clear; fi
#   - Remove a session tmp dir (only if it matches your pattern):
#       [[ -n "$DOTFILE_SESSION_TMP" ]] && rm -rf "$DOTFILE_SESSION_TMP"
#   - Guarded agent/tunnel shutdown (only if a PID file exists and matches):
#       # if [[ -f /tmp/cloudflared.$USER.pid ]]; then kill "$(cat /tmp/cloudflared.$USER.pid)"; fi
#   - Lock credential helper (example for rbw/bitwarden):
#       # rbw lock
#
# Safety notes and recommendations:
#   - This file runs on login-shell exit only; it will NOT be sourced for
#     non-login shells. If you need non-login-exit hooks, consider traps in
#     scripts or other mechanisms.
#   - Avoid destructive, global operations (e.g., `pkill -f tmux`) unless
#     you intentionally want to affect all processes. Prefer PID-files or
#     per-session markers to target only things started by your login.
#   - Make aggressive cleanup opt-in via environment variables (e.g.
#     `DOTFILES_CLEANUP_ON_LOGOUT=1`) or only act when a known PIDfile exists.
#   - Keep output minimal to avoid spammy logout messages; use stderr for
#     diagnostics if necessary.
#
# Where to put per-session markers (recommended pattern):
#   - Create a small directory under runtime or XDG cache for session state,
#     e.g. "$XDG_RUNTIME_DIR/dotfiles/$USER/$PID" or "$XDG_CACHE_HOME/dotfiles/session-$PID"
#   - Write PID files for background helpers you start on login and remove
#     them on logout.
#
# See: Zsh manual — Startup/Shutdown Files:
#   http://zsh.sourceforge.net/Doc/Release/Files.html
# -----------------------------------------------------------------------------

# Minimal default actions: flush history
fc -W 2>/dev/null || true

# End of .zlogout
