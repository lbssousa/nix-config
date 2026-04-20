# Módulo TPM2: Desbloqueio automático do volume LUKS via chip TPM2
#
# Este módulo configura o desbloqueio automático do LUKS usando o chip TPM2
# via systemd-cryptenroll. O TPM2 armazena a chave de criptografia e a libera
# somente se as medições de integridade do sistema (PCRs) corresponderem ao
# estado esperado, impedindo o acesso ao disco em caso de adulteração de hardware
# ou software de boot.
#
# ⚠️  AÇÃO NECESSÁRIA APÓS INSTALAÇÃO:
# Execute o seguinte comando para registrar o TPM2 no volume LUKS:
#
#   sudo systemd-cryptenroll \
#     --tpm2-device=auto \
#     --tpm2-pcrs=0+2+7 \
#     /dev/disk/by-partlabel/luks
#
# PCRs recomendados:
#   0 = Firmware UEFI (integridade do firmware)
#   2 = Código de opção UEFI (drivers ROM)
#   7 = Secure Boot state (estado do Secure Boot)
#
# Para revogar o acesso TPM2 (ex: antes de vender o hardware):
#   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/luks
#
# Referência: https://wiki.archlinux.org/title/Trusted_Platform_Module
{ pkgs, ... }:

{
  # Suporte ao TPM2 no NixOS
  security.tpm2 = {
    enable = true;
    # Interface PKCS#11 para aplicações que usam TPM2 via OpenSSL
    pkcs11.enable = true;
    # Variável de ambiente TCTI para ferramentas de userspace
    tctiEnvironment.enable = true;
  };

  # Módulos do kernel necessários para o TPM2
  # tpm_tis: driver para TPM 1.2/2.0 via LPC/SPI (maioria dos laptops e desktops)
  # tpm_crb: driver para TPM 2.0 via CRB (Command Response Buffer) - padrão moderno
  boot.initrd.kernelModules = [ "tpm_tis" "tpm_crb" ];

  # Ferramentas de userspace para gerenciar o TPM2
  environment.systemPackages = with pkgs; [
    tpm2-tools # Ferramentas de linha de comando para TPM2
    tpm2-tss # TCG Software Stack (TSS) para TPM2
  ];

  # Configurar o volume LUKS para aceitar desbloqueio via TPM2
  # O nome "crypted" corresponde ao nome definido em disko.nix
  #
  # crypttabExtraOpts instrui o systemd-cryptsetup a tentar o TPM2 primeiro;
  # se falhar (ex: PCRs modificados), pede a senha ao usuário como fallback.
  boot.initrd.luks.devices."crypted" = {
    crypttabExtraOpts = [
      "tpm2-device=auto" # Usar o TPM2 disponível automaticamente
      "tpm2-pcrs=0+2+7" # PCRs a verificar (firmware + Secure Boot state)
    ];
  };
}
