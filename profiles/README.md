# profiles

A profile is what a kind of laptop wants: every choice the modules leave open, in one file. A
machine file imports exactly one.

A profile sets, under `dotfiles`:

- `identity`: `personal`, `work` or `none`. A real identity links its git and ssh overlays and
  turns the 1Password app on; a profile never sets `apps."1password".enable` itself.
- `system.<concern>`: true or false for every file in `system/` (dock, finder, input,
  screenshots, security, appearance, display, animations).
- `apps.<name>.enable`: true or false for every optional app in `apps/` (raycast, ghostty,
  herdr, vscode, claude-code, conda, dust), plus the app's own knobs: `raycast.freeCmdSpace`,
  `vscode.extensions` (extras beyond the bundled set), `claude-code.profile` and `.ref` (both,
  when enabled).
- `shell.jgrid-net`: the jgrid.net fleet aliases.
- `repo.devToolchain`: linters, formatters and hyperfine for working on this repo.
- `packages.formulae`, `packages.casks`, `packages.mas`: free choices with no configuration
  attached. Not what base or an enabled app already provides (an assertion fails), and never
  a tap: `hashicorp/tap/terraform` implies its tap.

Every switch above has no default. Leave one out and evaluation fails naming it; that is how a
new concern or app is forced to be a decision on every profile.

`work.nix` has no machine file yet; `flake.nix` evaluates it under a synthetic machine so it
cannot rot. Keep it current when adding a switch.
