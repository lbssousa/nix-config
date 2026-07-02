# Módulo SELinux — habilita suporte a SELinux nos moldes do Fedora.
#
# O kernel linux_latest já inclui CONFIG_SECURITY_SELINUX=y e
# CONFIG_SECURITY_SELINUX_BOOTPARAM=y. O NixOS gerencia o parâmetro
# `lsm=` via `security.lsm`; adicionar "selinux" a essa lista ativa o LSM.
#
# Modo inicial: permissivo.
# Diferente do Fedora (enforcing + targeted), o NixOS exige adaptação da
# política para cobrir caminhos sob /nix/store. Até que isso seja feito,
# SELinux registra violações no audit log sem bloqueá-las.
#
# Para analisar as violações:
#   ausearch -m avc -ts recent
#   audit2allow -a
{ lib, pkgs, ... }:

{
  # Insere "selinux" no início da lista de LSMs ativos.
  # O NixOS transforma security.lsm em `lsm=selinux:landlock:yama:bpf` —
  # nunca use `security=` diretamente em boot.kernelParams (conflita com lsm=).
  security.lsm = lib.mkBefore [ "selinux" ];

  # `selinux=1` ativa o LSM quando CONFIG_SECURITY_SELINUX_BOOTPARAM=y.
  # `enforcing=0` força modo permissivo; remova após validar política para NixOS.
  boot.kernelParams = [
    "selinux=1"
    "enforcing=0"
  ];

  environment = {
    etc = {
      # Arquivo de configuração principal — espelha o /etc/selinux/config do Fedora.
      "selinux/config".text = ''
        # Configuração SELinux.
        # SELINUX: enforcing | permissive | disabled
        # Mude para enforcing após adaptar file_contexts para /nix/store.
        SELINUX=permissive

        # SELINUXTYPE: nome da política a ser carregada em /etc/selinux/<tipo>/.
        # O Fedora usa "targeted" (política derivada); o NixOS usa "refpolicy"
        # (referência base). A política binária (policy.XX) precisa ser compilada
        # com checkpolicy e carregada via load_policy antes de entrar em enforcing.
        SELINUXTYPE=refpolicy
      '';

      # Contextos da referência policy (selinux-refpolicy do nixpkgs).
      # Nota: este caminho é somente-leitura (Nix store). Para carregar módulos
      # adicionais em runtime, use um diretório gravável em /persist/etc/selinux/.
      "selinux/refpolicy".source = "${pkgs.selinuxPackages.selinux-refpolicy}/etc/selinux/refpolicy";
    };

    # Ferramentas SELinux — equivalentes ao grupo policycoreutils do Fedora.
    systemPackages = with pkgs.selinuxPackages; [
      policycoreutils # load_policy, restorecon, chcon, seinfo, setsebool, getenforce
      setools # seinfo, sesearch, findcon (análise de política)
      checkpolicy # compilador de política (.te + .fc + .if → policy.XX)
      semodule-utils # semodule, semodule_expand (gestão de módulos)
    ];
  };
}
