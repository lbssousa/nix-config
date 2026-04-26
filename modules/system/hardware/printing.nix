# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ pkgs, ... }:

{
  # CUPS - sistema de impressão
  services.printing = {
    enable = true;
    # Driver inkjet ESC/P-R da Epson (versão 1) - compatível com L4160, L3x50, etc.
    drivers = with pkgs; [
      epson-escpr # ESC/P-R driver versão 1 (L4160, L3x50, etc.)
      epson-escpr2 # ESC/P-R driver versão 2 (modelos mais novos)
    ];
  };

  # Avahi para descoberta de impressoras na rede
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Utilitário de impressora Epson: monitoramento de tinta, limpeza de cabeçotes, etc.
  # O pacote epson-printer-utility inclui o daemon ecbd (Epson Communication Bridge Daemon).
  #
  # NOTA: O hash SHA256 em pkgs/epson-printer-utility/package.nix precisa ser
  # atualizado antes do primeiro uso. Execute:
  #   nix-prefetch-url https://download3.ebz.epson.net/dsc/f/03/00/14/91/63/epson-printer-utility_1.1.2-1_amd64.deb
  # e substitua o valor do campo `hash` no arquivo acima.
  environment.systemPackages = with pkgs; [
    epson-printer-utility # GUI + ecbd daemon para impressoras Epson inkjet
    system-config-printer # Interface gráfica para configuração de impressoras CUPS
  ];

  # Serviço ecbd da Epson (Epson Communication Bridge Daemon)
  # Necessário para o utilitário epson-printer-utility funcionar corretamente.
  systemd.services.ecbd = {
    description = "Epson Communication Bridge Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.epson-printer-utility}/sbin/ecbd";
      PIDFile = "/run/ecbd.pid";
      Restart = "on-failure";
    };
  };
}
