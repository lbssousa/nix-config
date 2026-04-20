# Módulo de impressão: Epson ESC-P/R + ecbd.service
# Compatível com a multifuncional Epson L4160
{ lib, pkgs, ... }:

{
  # CUPS - sistema de impressão
  services.printing = {
    enable = true;
    # Driver ESC-P/R da Epson (versão 1) - compatível com L4160
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

  # Utilitário de impressora Epson (epson-printer-utility / ecbd.service)
  # O serviço ecbd gerencia comunicação bidirecional com impressoras Epson
  environment.systemPackages = with pkgs; [
    # epson-printer-utility não está no nixpkgs oficialmente.
    # Instale manualmente ou via Flatpak: com.epson.epsonscanutilities
    # O pacote abaixo é um wrapper para as ferramentas disponíveis:
    system-config-printer # Interface gráfica para configuração de impressoras
  ];

  # Serviço ecbd da Epson (Epson Communication Bridge Daemon)
  # Necessário para o utilitário epson-printer-utility funcionar corretamente.
  #
  # ⚠️  AÇÃO NECESSÁRIA ANTES DE HABILITAR:
  # 1. Instale o epson-printer-utility da Epson:
  #    https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX
  #    (baixe o arquivo .deb ou .rpm e instale manualmente via alien/dpkg/rpm)
  # 2. Atualize o path do binário abaixo (ExecStart) para o path correto
  # 3. Altere enable = false para enable = true neste arquivo
  # 4. Execute: sudo nixos-rebuild switch --flake /etc/nixos#<host>
  #
  # O serviço está DESABILITADO por padrão para evitar erros na ausência do binário.
  systemd.services.ecbd = {
    description = "Epson Communication Bridge Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    # DESABILITADO por padrão - habilite após instalar o epson-printer-utility
    enable = lib.mkDefault false;
    serviceConfig = {
      Type = "forking";
      # Atualize este path para o binário ecbd após instalar o epson-printer-utility:
      ExecStart = lib.mkDefault "/usr/bin/ecbd";
      PIDFile = "/run/ecbd.pid";
      Restart = "on-failure";
    };
  };
}
