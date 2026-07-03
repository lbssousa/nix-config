# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ pkgs, ... }:

{
  # Fila CUPS declarativa para sobreviver ao root efêmero (preservation).
  #
  # Importante: o epson-printer-utility não lida bem com filas dnssd:// e
  # implicitclass://; por isso usamos URI baseada em IP (socket://).
  hardware.printers = {
    ensurePrinters = [
      {
        name = "L4160_IP";
        location = "Wi-Fi";
        description = "EPSON L4160 Series";
        deviceUri = "socket://EPSONE0321F.local:9100";
        model = "epson-inkjet-printer-escpr/Epson-L4160_Series-epson-escpr-en.ppd";
      }
    ];
    ensureDefaultPrinter = "L4160_IP";
  };

  services = {
    # CUPS - sistema de impressão
    printing = {
      enable = true;
      # Driver inkjet ESC/P-R da Epson (versão 1) - compatível com L4160, L3x50, etc.
      # epson-printer-utility também é incluído aqui para que o backend CUPS (ecblp)
      # seja descoberto pelo CUPS automaticamente via CUPS_SERVERBIN.
      drivers = with pkgs; [
        epson-escpr # ESC/P-R driver versão 1 (L4160, L3x50, etc.)
        epson-escpr2 # ESC/P-R driver versão 2 (modelos mais novos)
        epson-printer-utility # backend CUPS ecblp para comunicação com ecbd
      ];
    };

    # Avahi para descoberta de impressoras na rede
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Regras udev do epson-printer-utility (79-udev-epson.rules):
    # permite acesso de leitura/escrita ao dispositivo USB da impressora Epson.
    udev.packages = [ pkgs.epson-printer-utility ];
  };

  # SNMP — necessário para o epson-printer-utility descobrir impressoras Wi-Fi.
  #
  # A GUI faz broadcast SNMP para 255.255.255.255:161 a partir de uma porta
  # efêmera local. A impressora responde em unicast com sport=161, dport=efêmera.
  # O conntrack não associa essa resposta ao broadcast de saída (IPs divergem),
  # então o nixos-fw descarta o pacote por padrão.
  #
  # A correção é permitir explicitamente UDP com sport 161 na entrada.
  # allowedUDPPorts abre dpt:161 (direção errada); é necessário extraCommands
  # para criar a regra com sport:161.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p udp --sport 161 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p udp --sport 161 -j nixos-fw-accept 2>/dev/null || true
  '';

  # Utilitário de impressora Epson: monitoramento de tinta, limpeza de cabeçotes, etc.
  # O pacote epson-printer-utility inclui o daemon ecbd (Epson Communication Bridge Daemon).
  #
  # NOTA: ao atualizar para uma nova versão, consulte os passos no cabeçalho de
  # pkgs/epson-printer-utility/package.nix para obter a nova URL via API da Epson
  # e calcular o hash SHA256 do arquivo.
  environment.systemPackages = with pkgs; [
    epson-printer-utility # GUI + ecbd daemon para impressoras Epson inkjet
    system-config-printer # Interface gráfica para configuração de impressoras CUPS
  ];

  # Serviço ecbd da Epson (Epson Communication Bridge Daemon)
  # Necessário para o utilitário epson-printer-utility funcionar corretamente.
  # WorkingDirectory aponta para o diretório de suporte do daemon na Nix store,
  # onde ecbd.conf e demais arquivos de configuração estão instalados.
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
