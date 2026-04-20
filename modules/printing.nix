# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ config, lib, pkgs, ... }:

{
  # CUPS - sistema de impressão
  services.printing = {
    enable = true;
    # Driver ESC-P/R da Epson (versão 1) - compatível com L4160
    drivers = with pkgs; [
      epson-escpr     # ESC/P-R driver versão 1 (L4160, L3x50, etc.)
      epson-escpr2    # ESC/P-R driver versão 2 (modelos mais novos)
    ];
  };

  # Avahi para descoberta de impressoras na rede
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Utilitário de impressora Epson (epson-printer-utility / ecbd.service)
  # O serviço ecbd gerencia comunicação bidirecional com impressoras Epson
  environment.systemPackages = with pkgs; [
    # epson-printer-utility não está no nixpkgs oficialmente.
    # Instale manualmente ou via Flatpak: com.epson.epsonscanutilities
    # O pacote abaixo é um wrapper para as ferramentas disponíveis:
    system-config-printer  # Interface gráfica para configuração de impressoras
  ];

  # Serviço ecbd da Epson (Epson Communication Bridge Daemon)
  # Necessário para o utilitário epson-printer-utility funcionar corretamente.
  # NOTA: O pacote epson-printer-utility (que contém o binário ecbd) não está
  # disponível no nixpkgs oficial. Instale-o manualmente ou configure o path
  # abaixo após a instalação manual do pacote da Epson.
  #
  # Para instalar manualmente (arquivo .deb ou .rpm da Epson):
  # https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX
  #
  # Após instalar, defina o path correto em:
  # systemd.services.ecbd.serviceConfig.ExecStart
  systemd.services.ecbd = {
    description = "Epson Communication Bridge Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    # Enable = false por padrão até que o binário esteja instalado
    enable = lib.mkDefault false;
    serviceConfig = {
      Type = "forking";
      # Atualize este path após instalar o epson-printer-utility:
      # ExecStart = "/opt/epson-printer-utility/bin/ecbd";
      ExecStart = lib.mkDefault "/usr/bin/ecbd";
      PIDFile = "/run/ecbd.pid";
      Restart = "on-failure";
    };
  };
}
