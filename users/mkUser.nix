# Função auxiliar para criar definições de usuário NixOS
# Uso: import ./mkUser.nix { inherit pkgs lib; } { username = ...; ... }
#
# NOTA: A configuração do Home Manager é gerida como módulo NixOS (home-manager.users.<name>
# em dendritic/flake/home-nixos-module.nix). Consulte home/users/<usuario>/home.nix
# para customizações por usuário.
#
# NOTA: O nome completo (description) é definido via outputs do flake nix-secrets
# (inputs.nix-secrets.${username}.fullName). Não deve ser definido aqui.
{ pkgs, lib }:
{
  username,
  # UID numérico fixo. SEMPRE defina para evitar reatribuição após adicionar/remover
  # usuários, o que causaria incompatibilidade de propriedade nos arquivos do $HOME.
  uid ? null,
  # Define se o usuário pertence ao grupo "wheel" (sudo). Padrão: false.
  hasSudo ? false,
}:

{
  # Cria um grupo com o mesmo nome do usuário (necessário para aplicativos que
  # chamam `chown username:username`, como o epson-printer-utility).
  users.groups.${username} = { };

  users.users.${username} = {
    isNormalUser = true;
  }
  // lib.optionalAttrs (uid != null) { inherit uid; }
  // {
    # Grupos essenciais para desktop com GNOME + containers
    extraGroups = [
      "networkmanager" # Gerenciar conexões de rede
      "video" # Acesso à GPU
      "audio" # Acesso ao áudio
      "plugdev" # Acesso a dispositivos USB
      "dialout" # Portas seriais
      "docker" # Compatibilidade com Docker (Podman)
    ]
    ++ lib.optionals hasSudo [
      "wheel" # sudo
    ];
    shell = pkgs.zsh; # Shell padrão (Zsh)
    # Senha inicial: o usuário será solicitado a trocá-la no primeiro login.
    # Se uma senha personalizada for definida durante a instalação (ver INSTALLATION.md),
    # a troca não será exigida.
    initialPassword = "nixos";
  };

  # ─────────────────────────────────────────────────────────────────────────
  # Preservação seletiva do diretório home
  # ─────────────────────────────────────────────────────────────────────────
  #
  # /home é tmpfs — efêmero a cada boot. O módulo preservation bind-monta
  # os itens abaixo de /persist/home/<usuario>/ no diretório home do usuário.
  # Tudo o que não está listado aqui é recriado pelo Home Manager ou descartado.
  #
  # Para migrar uma instalação existente:
  #   run0 rsync -a /home/<usuario>/Documentos/ /persist/home/<usuario>/Documentos/
  #   (repita para cada diretório listado abaixo)
  preservation.preserveAt."/persist".users.${username} = {
    directories = [
      # ── Diretórios XDG padrão (dados do usuário) ──────────────────────
      "Área de Trabalho"
      "Documentos"
      "Downloads"
      "Imagens"
      "Modelos"
      "Música"
      "Projetos"
      "Público"
      "Vídeos"

      # ── Identidade e segurança ─────────────────────────────────────────
      ".ssh" # Chaves SSH, known_hosts, authorized_keys
      ".gnupg" # Chaves GPG, base de confiança, stubs do YubiKey

      # ── Navegadores (pacotes nixpkgs — dados não geridos pelo HM) ──────
      ".mozilla" # Firefox: favoritos, sessões, extensões, senhas
      {
        directory = ".config/BraveSoftware";
        mode = "0700"; # Brave armazena credenciais aqui
      }

      # ── Flatpak: dados por aplicação ───────────────────────────────────
      ".var/app" # Vault do Bitwarden, dados de todos os Flatpaks
      ".config/autostart" # Autostart dos Flatpaks (monitorado pelo fix-autostart)

      # ── Estado GNOME / desktop ─────────────────────────────────────────
      # Nota: .config/dconf NÃO é preservado intencionalmente.
      # Configurações dconf que devem sobreviver ao reboot devem ser declaradas
      # via programs.dconf.profiles.*.databases no NixOS (gravadas em /etc/dconf/,
      # que é gerenciado pelo sistema e independe do home). O dconf.settings do
      # Home Manager escreve em ~/.config/dconf/user apenas na ativação —
      # não use-o para settings que devem persistir em home efêmero.
      ".local/share/keyrings" # GNOME keyring: senhas de Wi-Fi e apps
      ".local/share/applications" # Arquivos .desktop do usuário e de Flatpaks

      # ── Configuração de apps (não geridos pelo HM) ─────────────────────
      ".config/keepassxc" # Preferências e caminho do banco de dados

      # ── Ferramentas de shell ───────────────────────────────────────────
      ".local/share/zoxide" # Base de dados de frequência do zoxide (cd inteligente)
      ".local/share/fish" # Histórico do Fish e cache de funções

      # ── Containers rootless (Podman sem root) ──────────────────────────
      ".local/share/containers" # Imagens e volumes Podman do usuário
    ];

    files = [
      ".bash_history"
      ".zsh_history"
      ".config/user-dirs.dirs"
      ".config/user-dirs.locale"
    ];
  };
}
