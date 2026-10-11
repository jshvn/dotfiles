# machines

Each physical laptop has one file. The file has the name of the laptop. A machine file
contains only the data that a profile cannot contain. This data is the platform of the laptop.
The profile that the file imports supplies all other configuration.

```nix
{
  imports = [ ../profiles/personal ];
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

`flake.nix` reads this directory. Each `<name>.nix` file becomes
`darwinConfigurations.<name>`. `flake.nix` sets `<name>` as the `hostName`, `computerName` and
`localHostName` of that configuration. `task check` evaluates each one.

You must select the machine explicitly. `task setup -- <name>` writes the name to
`$XDG_STATE_HOME/dotfiles/machine`. Each task reads that file. No part of this repository gets
the machine name from the live hostname.

## Add a machine

1. Create `machines/<name>.nix` from the example above.
2. On the laptop, enter `uname -m`. Use the output to set `nixpkgs.hostPlatform`:
   - For `arm64`, set `aarch64-darwin`.
   - For `x86_64`, set `x86_64-darwin`.
3. Enter `git add machines/<name>.nix`.
4. Enter `task check`.
5. On the laptop, do the procedure in "Install" in the root README. Use `<name>` as the
   machine.
6. Describe the machine in `docs/MACHINES.md`.

The file name is the hostname. To change the hostname of a machine, rename this file. Then
enter `task setup -- <new-name>` and `task install`.
