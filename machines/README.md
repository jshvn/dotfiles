# machines

One file per physical laptop, named after it. A machine file says what no profile can: the
names the laptop answers to and its platform. Everything else is the profile it imports.

```nix
{
  imports = [ ../profiles/personal ];
  networking = {
    hostName = "lerasium";
    computerName = "lerasium";
    localHostName = "lerasium";
  };
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

`flake.nix` reads this directory: every `<name>.nix` is a `darwinConfigurations.<name>`, and
`task check` evaluates each one. Selection is explicit: `task setup -- <name>` writes the name
to `$XDG_STATE_HOME/dotfiles/machine`, and every task reads that file. Nothing infers the
machine from the live hostname.

## Adding a machine

1. Create `machines/<name>.nix` as above; `uname -m` on the laptop decides
   `nixpkgs.hostPlatform` (`aarch64-darwin` for `arm64`, `x86_64-darwin` for `x86_64`).
2. `git add` it and run `task check`.
3. On the laptop: `./bootstrap.zsh <name>` (the root README lists what a factory-fresh Mac
   needs first).
4. Describe it in `docs/MACHINES.md`.

The hostname lives here, so renaming a machine is an edit and a switch.
