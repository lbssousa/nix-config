# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ pkgs, ... }:

{
  # Fila CUPS declarativa para sobreviver ao root efêmero (impermanence).
  #
  # Importante: o epson-printer-utility não lida bem com filas dnssd:// e
  # implicitclass://; por isso usamos URI baseada em IP (socket://).
  hardware.printers = {
    ensurePrinters = [
      {
        name = "L4160_IP";
        location = "Wi-Fi";
        description = "EPSON L4160 Series";
        deviceUri = "socket://192.168.1.75:9100";
        model = "epson-inkjet-printer-escpr/Epson-L4160_Series-epson-escpr-en.ppd";
      }
    ];
    ensureDefaultPrinter = "L4160_IP";
  };

  # CUPS - sistema de impressão
  services.printing = {
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
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # SNMP (UDP/161) — necessário para o epson-printer-utility descobrir
  # impressoras Wi-Fi/Ethernet.
  #
  # A GUI faz broadcast SNMP em 255.255.255.255:161 (ver símbolos
  # `snmpFindStart`, `epsmpSetBroadCast`, `SnmpTransact` no binário). As
  # respostas vêm em unicast do IP da impressora (porta de origem 161),
  # mas o conntrack do nixos-fw não associa essas respostas à entrada do
  # broadcast (IPs de destino divergem) e descarta os pacotes. Abrir 161
  # explicitamente nas regras de entrada resolve a descoberta de rede.
  #
  # Sem isso, o epson-printer-utility só enxerga impressoras USB (via ecbd)
  # e impressoras já cadastradas no CUPS com URI baseada em IP
  # (socket://, lpd:// ou ipp://); URIs dnssd:// e implicitclass://
  # não são reconhecidas pelo binário.
  networking.firewall.allowedUDPPorts = [ 161 ];

  # Regras udev do epson-printer-utility (79-udev-epson.rules):
  # permite acesso de leitura/escrita ao dispositivo USB da impressora Epson.
  services.udev.packages = [ pkgs.epson-printer-utility ];

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
