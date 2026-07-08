# Printing module: Epson ESC-P/R + ecbd.service
# Compatible with the Epson L4160 all-in-one
{ pkgs, ... }:

{
  # Declarative CUPS queue to survive the ephemeral root (preservation).
  #
  # Important: epson-printer-utility doesn't handle dnssd:// and
  # implicitclass:// queues well; so we use an IP-based URI (socket://).
  hardware.printers = {
    ensurePrinters = [
      {
        name = "L4160_IP";
        location = "Wi-Fi";
        description = "EPSON L4160 Series";
        deviceUri = "socket://EPSONE0321F.local:9100";
        model = "epson-inkjet-printer-escpr/Epson-L4160_Series-epson-escpr-en.ppd";
        # Default CUPS error-policy is "stop-printer": any filter failure
        # (e.g. pdftopdf/QPDF rejecting a malformed PDF) disables the whole
        # queue, requiring a manual `cupsenable`. abort-job just drops the
        # offending job and keeps the queue accepting new ones.
        ppdOptions."printer-error-policy" = "abort-job";
      }
    ];
    ensureDefaultPrinter = "L4160_IP";
  };

  services = {
    # CUPS - printing system
    printing = {
      enable = true;
      # Epson ESC/P-R inkjet driver (version 1) - compatible with L4160, L3x50, etc.
      # epson-printer-utility is also included here so the CUPS backend (ecblp)
      # is discovered by CUPS automatically via CUPS_SERVERBIN.
      drivers = with pkgs; [
        epson-escpr # ESC/P-R driver version 1 (L4160, L3x50, etc.)
        epson-escpr2 # ESC/P-R driver version 2 (newer models)
        epson-printer-utility # ecblp CUPS backend for communication with ecbd
      ];
    };

    # Avahi for network printer discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # epson-printer-utility udev rules (79-udev-epson.rules):
    # grants read/write access to the Epson printer's USB device.
    udev.packages = [ pkgs.epson-printer-utility ];
  };

  # SNMP — needed for epson-printer-utility to discover Wi-Fi printers.
  #
  # The GUI broadcasts SNMP to 255.255.255.255:161 from a local ephemeral
  # port. The printer replies via unicast with sport=161, dport=ephemeral.
  # conntrack doesn't associate that reply with the outgoing broadcast (IPs
  # differ), so nixos-fw drops the packet by default.
  #
  # The fix is to explicitly allow inbound UDP with sport 161.
  # allowedUDPPorts opens dpt:161 (wrong direction); extraCommands is
  # needed to create the rule with sport:161.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p udp --sport 161 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p udp --sport 161 -j nixos-fw-accept 2>/dev/null || true
  '';

  # Epson printer utility: ink monitoring, head cleaning, etc.
  # The epson-printer-utility package includes the ecbd daemon (Epson Communication Bridge Daemon).
  #
  # NOTE: when upgrading to a new version, see the steps in the header of
  # pkgs/epson-printer-utility/package.nix to get the new URL via Epson's
  # API and compute the file's SHA256 hash.
  environment.systemPackages = with pkgs; [
    epson-printer-utility # GUI + ecbd daemon for Epson inkjet printers
    system-config-printer # GUI for configuring CUPS printers
  ];

  # Epson's ecbd service (Epson Communication Bridge Daemon)
  # Required for the epson-printer-utility to work correctly.
  # WorkingDirectory points to the daemon's support directory in the Nix
  # store, where ecbd.conf and other config files are installed.
  systemd.services.ecbd = {
    description = "Epson Communication Bridge Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.epson-printer-utility}/lib/epson-backend/ecbd";
      WorkingDirectory = "${pkgs.epson-printer-utility}/lib/epson-backend";
      PIDFile = "/run/ecbd.pid";
      Restart = "on-failure";
    };
  };
}
