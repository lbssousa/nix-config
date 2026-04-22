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

  # Usuário dedicado para instalação system-wide do Homebrew
  users.users.linuxbrew = {
    isSystemUser = true;
    group = "linuxbrew";
    home = "/home/linuxbrew";
    createHome = true;
    description = "Homebrew system user";
  };
  users.groups.linuxbrew = { };

  # Garantir que o diretório do Homebrew seja persistente entre boots.
  # user/group explícitos para que /persist/home/linuxbrew seja criado com a
  # propriedade correta, permitindo que o usuário linuxbrew escreva nele.
  environment.persistence."/persist".directories = [
    {
      directory = "/home/linuxbrew";
      user = "linuxbrew";
      group = "linuxbrew";
      mode = "0755";
    }
  ];

  # Instalar Homebrew automaticamente na primeira inicialização com rede disponível.
  # Comportamento idêntico ao serviço de Flatpaks: oneshot com Restart=on-failure,
  # só executa enquanto o brew não estiver instalado (ConditionPathExists).
  systemd.services.install-homebrew = {
    description = "Instalar Homebrew (Linuxbrew) automaticamente";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "local-fs.target"
    ];
    wants = [ "network-online.target" ];
    unitConfig = {
      # Pula se o brew já estiver instalado (idempotente)
      ConditionPathExists = "!/home/linuxbrew/.linuxbrew/bin/brew";
      StartLimitBurst = 5;
      StartLimitIntervalSec = "300";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "linuxbrew";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
      Environment = [
        "NONINTERACTIVE=1"
        "HOME=/home/linuxbrew"
      ];
    };
    # Ferramentas necessárias para o instalador do Homebrew
    path = with pkgs; [
      bash
      coreutils
      git
      curl
      gcc
      gnumake
      binutils
    ];
    script = ''
      ${pkgs.curl}/bin/curl -fsSL \
        "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \
        | ${pkgs.bash}/bin/bash
    '';
  };
}
