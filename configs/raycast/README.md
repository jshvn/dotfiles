# Tool: raycast

Raycast script commands. Raycast reads them from a directory registered in
the app, not from `~/.config`, so nothing here is symlinked.

## Files

- `random-email.zsh` -- "Random Email" command. Takes a prefix argument,
  copies `<prefix>.<8 random lowercase alphanumerics>@jgrid.net` to the
  clipboard, and shows the result as a HUD toast.

## Setup (one-time, per machine)

Raycast > Settings > Script Commands > Add Directories, then pick
`${DOTFILEDIR}/configs/raycast`. Raycast stores this path in its own settings
sync; there is no defaults key to declare it from here.

## Feature gate

None. The directory is inert unless Raycast is pointed at it.
