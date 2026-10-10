# 1password

## Turning on the SSH agent

Once per Mac, by hand: 1Password > Settings > Developer > Use the SSH Agent. The setting
persists. Until it is on, `task validate` crosses on `ssh-add -L does not offer
profiles/<profile>/key.pub`, even though the `SSH_AUTH_SOCK` check passes. After turning it on,
lock and unlock 1Password so the agent reads `agent.toml`.

This is the one part of the app the switch cannot declare. 1Password 8 offers no way to turn
the agent on outside its UI (checked 2026-10-10):

- The [getting-started guide](https://www.1password.dev/ssh/get-started) gives only the
  Settings toggle.
- The [agent config file](https://www.1password.dev/ssh/agent/config) (`agent.toml`, linked
  from the profile) chooses which keys the agent offers. It cannot turn the agent on.
- The [MDM settings](https://support.1password.com/mobile-device-management/) (preference
  domain `com.1password.1password`, MDM only, not `defaults write`) have no SSH agent key; see
  the [sample profile](https://support.1password.com/files/1Password_8_sample_profile.mobileconfig).
- The app stores the switch as `sshAgent.enabled` in
  `~/Library/Group Containers/2BUA8C4S2C.com.1password/Library/Application Support/1Password/Data/settings/settings.json`,
  but every value there has a matching signature in `authTags`, so a value written from
  outside the app has no valid signature. It is undocumented in any case.

If a supported switch appears (an MDM key in the sample profile, an `agent.toml` field, an
`op` command), declare it in `default.nix` and remove this section and the agent note in the
repo README's fresh-Mac list. The [release notes](https://releases.1password.com/mac/stable/)
are where it would be announced.
