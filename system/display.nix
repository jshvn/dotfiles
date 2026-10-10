{ config, lib, ... }:
{
  options.dotfiles.system.display = lib.mkOption {
    type = lib.types.bool;
    description = "built-in panel at the More Space HiDPI preset";
  };

  config = lib.mkIf config.dotfiles.system.display {
    # a live CoreGraphics reconfiguration, not a defaults key: the Swift helper beside this file
    # is copied into the store with the generation that runs it
    system.activationScripts.postActivation.text = ''
      sudo -u josh /usr/bin/swift ${./display-mode.swift} apply
    '';
  };
}
