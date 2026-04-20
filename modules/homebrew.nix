# Módulo Homebrew: Suporte ao Linuxbrew/Homebrew
# Permite instalar ferramentas CLI via Homebrew, similar ao Fedora Silverblue/Bluefin
{ lib, pkgs, ... }:

{
  environment = {
    # Dependências necessárias para o Homebrew funcionar no Linux
    systemPackages = with pkgs; [
      # Ferramentas básicas que o Homebrew precisa
      gcc
      gnumake
      binutils
      # curl e git já são instalados em packages.nix
    ];

    # Variáveis de ambiente para o Homebrew (Linuxbrew)
    # O Homebrew é instalado em /home/linuxbrew/.linuxbrew por padrão no Linux
    variables = {
      HOMEBREW_PREFIX = lib.mkDefault "/home/linuxbrew/.linuxbrew";
      HOMEBREW_CELLAR = lib.mkDefault "/home/linuxbrew/.linuxbrew/Cellar";
      HOMEBREW_REPOSITORY = lib.mkDefault "/home/linuxbrew/.linuxbrew/Homebrew";
    };

    # Adicionar Homebrew ao PATH para todos os usuários via /etc/profile
    extraInit = ''
      # Homebrew (Linuxbrew)
      if [ -d "/home/linuxbrew/.linuxbrew" ]; then
        export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
        export MANPATH="/home/linuxbrew/.linuxbrew/share/man:$MANPATH"
        export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:$INFOPATH"
      fi
    '';
  };

  # Script de instalação do Homebrew (executar manualmente após instalação do NixOS):
  # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Usuário dedicado para instalação system-wide do Homebrew
  users.users.linuxbrew = {
    isSystemUser = true;
    group = "linuxbrew";
    home = "/home/linuxbrew";
    createHome = true;
    description = "Homebrew system user";
  };
  users.groups.linuxbrew = { };

  # Garantir que o diretório do Homebrew seja persistente entre boots
  environment.persistence."/persist".directories = [ "/home/linuxbrew" ];
}
