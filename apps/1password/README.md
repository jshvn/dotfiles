# 1password

## Turn on the SSH agent

Do this procedure one time on each Mac:

1. In 1Password, go to Settings > Developer.
2. Select Use the SSH Agent. 1Password keeps this setting.
3. Lock 1Password.
4. Unlock 1Password. The agent then reads `agent.toml`.

If the agent is off, `task validate` reports this failure:
`ssh-add -L does not offer profiles/<profile>/key.pub`. The `SSH_AUTH_SOCK` check passes, but
this check fails.

## Why the switch cannot turn on the agent

This setting is the only part of 1Password that the switch cannot declare. 1Password 8 has no
method to turn on the agent outside its UI. This was checked on 2026-10-10.

- The [getting-started guide](https://www.1password.dev/ssh/get-started) gives only the
  setting in Settings.
- The [agent configuration file](https://www.1password.dev/ssh/agent/config), `agent.toml`,
  selects the keys that the agent offers. It cannot turn on the agent. The profile supplies
  this file.
- The [MDM settings](https://support.1password.com/mobile-device-management/) have no key for
  the SSH agent. See the
  [sample profile](https://support.1password.com/files/1Password_8_sample_profile.mobileconfig).
  These settings use the preference domain `com.1password.1password`. Only MDM can write
  them. `defaults write` cannot.
- The app keeps the setting as `sshAgent.enabled` in
  `~/Library/Group Containers/2BUA8C4S2C.com.1password/Library/Application Support/1Password/Data/settings/settings.json`.
  Each value in that file has a signature in `authTags`. Thus a value that you write from
  outside the app has no valid signature. Also, this file has no documentation.

If 1Password adds a supported method, declare it in `default.nix`. The method can be an MDM
key in the sample profile, an `agent.toml` field or an `op` command. Then delete this README.
Also remove the step that turns on the SSH agent from "After the install" in the root README.
The [release notes](https://releases.1password.com/mac/stable/) will announce a new method.
