# NextDNS: the formula, and a launchd daemon that runs it as a DNS-over-HTTPS proxy on
# 127.0.0.1:53 for one NextDNS profile, for Proton VPN. With the VPN on, the tunnel's DNS wins
# over every other setting, so Proton's custom DNS server is 127.0.0.1, set by hand once per Mac
# (docs/MACHINES.md): Proton keeps it in a sandboxed container the switch cannot write. Custom
# DNS turns NetShield off, and Proton keeps its own server second, so a stopped daemon costs
# filtering, not DNS. With the VPN off, macOS uses the NextDNS configuration profile, also
# installed by hand once per Mac, and never this proxy. The daemon changes no network service:
# -auto-activate sets DNS on every one, Proton's VPN service included, and Proton's WireGuard
# handshake then fails. -report-client-info sends the computer name, which the switch sets from
# the machine file. task validate reads the path in use back. The proxy's hold on port 53 breaks
# DNS inside Apple container VMs, so with the container runtime installed, container/config.toml
# gives containers their own resolvers.
{ config, lib, ... }:
let
  cfg = config.dotfiles.apps.nextdns;
  label = config.launchd.daemons.nextdns.serviceConfig.Label;
in
{
  options.dotfiles.apps.nextdns = {
    enable = lib.mkOption { type = lib.types.bool; };
    profile = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9a-f]+");
      default = null;
      description = "the NextDNS profile ID, the last part of its DoH URL (https://dns.nextdns.io/<id>)";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.enable == (cfg.profile != null);
        message = "apps.nextdns: enable and profile travel together";
      }
    ];
    dotfiles.provided.formulae = lib.mkIf cfg.enable [ "nextdns" ];
    dotfiles.links.".config/container/config.toml" = lib.mkIf (
      cfg.enable && config.dotfiles.repo.devToolchain
    ) "apps/nextdns/container/config.toml";
    launchd.daemons.nextdns = lib.mkIf cfg.enable {
      serviceConfig = {
        ProgramArguments = [
          "${config.homebrew.prefix}/bin/nextdns"
          "run"
          "-listen"
          "127.0.0.1:53"
          "-profile"
          cfg.profile
          "-report-client-info"
        ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
    # launchd activation runs before Homebrew's, so on a Mac's first switch the daemon loads
    # before its binary exists; this starts it once Homebrew has installed it, and leaves a
    # running one alone. ponytail: a brew upgrade of nextdns takes effect at the next reboot;
    # restart it here on every switch (about 1 s without DNS) if that is ever too slow.
    system.activationScripts.postActivation.text = lib.mkIf cfg.enable ''
      launchctl print system/${label} 2>/dev/null | grep -q 'state = running' \
        || launchctl kickstart system/${label} \
        || echo "nextdns: the daemon did not start; task validate reads it back" >&2
    '';
  };
}
