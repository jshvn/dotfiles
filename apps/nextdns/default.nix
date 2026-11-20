# NextDNS: the formula, and a launchd daemon that runs it as a DNS-over-HTTPS proxy on
# 127.0.0.1:53 for one NextDNS profile: the Mac's DNS with Proton VPN on or off. The switch
# points the physical network services at the proxy (a service a Mac lacks is skipped). The
# daemon itself changes no service: -auto-activate sets DNS on every one, Proton's VPN service
# included, and Proton's WireGuard handshake then fails. With the VPN on, the tunnel's DNS wins,
# so Proton's custom DNS server is 127.0.0.1, set by hand once per Mac (docs/MACHINES.md): Proton
# keeps it in a sandboxed container the switch cannot write. Custom DNS turns NetShield off. A
# DNS configuration profile overrides the proxy while the VPN is off, so none is installed.
# -detect-captive-portals lets the proxy use the network's own DNS after a network change (the
# VPN going up or down, a hotel login page) while DoH does not answer. -report-client-info sends
# the computer name, which the switch sets from the machine file. task validate reads the path
# back. The proxy's hold on port 53 breaks DNS inside Apple container VMs, so with the container
# runtime installed, container/config.toml gives containers their own resolvers.
# ponytail: turning the app off leaves 127.0.0.1 on those services; `networksetup
# -setdnsservers <service> empty` gives each back to DHCP.
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
          "-detect-captive-portals"
          "-report-client-info"
        ];
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
    networking = lib.mkIf cfg.enable {
      knownNetworkServices = [
        "Wi-Fi"
        "USB 10/100/1000 LAN"
      ];
      dns = [ "127.0.0.1" ];
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
