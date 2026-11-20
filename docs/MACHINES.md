# Machine Reference

## What This Is

Per-machine prose the Nix files cannot express: purpose, hardware narrative, role, special
handling. Declarative state lives in `machines/<name>.nix` (its file name is the name a laptop
answers to; its platform, the profile it imports) and `profiles/<name>/` (every System Settings concern,
every optional app, the shell and pipeline knobs, free packages, and the identity files) and is
authoritative; `task show` prints the evaluated result for the selected machine.

Nothing here enumerates packages or switches. That duplication drifts, and the profile already
answers it in one file.

## lerasium

- Purpose: the personal MacBook Pro, daily driver for personal projects and AI/CLI work.
- Hardware: Apple Silicon (`nixpkgs.hostPlatform = "aarch64-darwin"`).
- Profile: `personal`. Full GUI, dev and personal set; the personal git/ssh identity with
  SSH auth and commit signing through the 1Password agent; the jgrid.net aliases.
- Special handling, each by hand, once: Raycast's script-command directory (`apps/raycast/`)
  is registered in Raycast; the NextDNS configuration profile for profile `2bb66f`, with the
  device name `lerasium` (apple.nextdns.io), is the only DNS configuration profile installed
  (System Settings > General > Device Management); Proton VPN's custom DNS server is
  `127.0.0.1` (`apps/nextdns/`).

## harmonium

- Purpose: the second personal MacBook.
- Hardware: assumed Apple Silicon; confirm `uname -m` before its first switch and change
  `nixpkgs.hostPlatform` in `machines/harmonium.nix` to `x86_64-darwin` if it prints `x86_64`.
- Profile: `personal`, identical to lerasium's.
- Special handling: `./bootstrap.zsh harmonium` installs it. Then, by hand, once, as on
  lerasium: the NextDNS configuration profile, with the device name `harmonium`, and Proton
  VPN's custom DNS server `127.0.0.1`.

## work (profile only)

- Purpose: the work-issued MacBook carrying the work git/ssh identity.
- Status: no machine file yet. `profiles/work/` is kept current and the flake check
  evaluates it under a synthetic machine, so it cannot rot. When the laptop comes into scope,
  fill in the work email (`profiles/work/git`) and add `profiles/work/key.pub` and the key's
  item in `agent.toml`, then add `machines/<its-name>.nix` importing it.
- Role: primary work development machine; the toolchain is a subset of personal's, without
  the jgrid.net aliases or the `*.jgrid.net` SSH host blocks.

## CI

There is no CI machine. GitHub Actions evaluates every machine file and every profile inside
the pinned `nixos/nix` image (`task check`) and runs lint and the hermetic smoke tests; a
macOS runner builds lerasium's closure. It never switches a Mac.
