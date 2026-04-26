# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ pkgs, ... }:

{
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
