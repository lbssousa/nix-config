# TPM2 module: automatic LUKS volume unlock via the TPM2 chip
#
# This module sets up automatic LUKS unlock using the TPM2 chip via
# systemd-cryptenroll. The TPM2 stores the encryption key and only releases
# it if the system's integrity measurements (PCRs) match the expected
# state, blocking disk access in case of hardware or boot software tampering.
#
# ⚠️  ACTION REQUIRED AFTER INSTALLATION:
# Run the following command to enroll the TPM2 for the LUKS volume:
#
#   sudo systemd-cryptenroll \
#     --tpm2-device=auto \
#     --tpm2-pcrs=0+2+7 \
#     /dev/disk/by-partlabel/luks
#
# Recommended PCRs:
#   0 = UEFI firmware (firmware integrity)
#   2 = UEFI option code (ROM drivers)
#   7 = Secure Boot state
#
# To revoke TPM2 access (e.g. before selling the hardware):
#   sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-partlabel/luks
#
# Reference: https://wiki.archlinux.org/title/Trusted_Platform_Module
{ pkgs, ... }:

{
  # TPM2 support in NixOS
  security.tpm2 = {
    enable = true;
    # PKCS#11 interface for applications using TPM2 via OpenSSL
    pkcs11.enable = true;
    # TCTI environment variable for userspace tools
    tctiEnvironment.enable = true;
  };

  # Kernel modules needed for TPM2
  # tpm_tis: driver for TPM 1.2/2.0 via LPC/SPI (most laptops and desktops)
  # tpm_crb: driver for TPM 2.0 via CRB (Command Response Buffer) - modern standard
  boot.initrd.kernelModules = [
    "tpm_tis"
    "tpm_crb"
  ];

  # Userspace tools to manage the TPM2
  environment.systemPackages = with pkgs; [
    tpm2-tools # Command-line tools for TPM2
    tpm2-tss # TCG Software Stack (TSS) for TPM2
  ];

  # Configure the LUKS volume to accept TPM2 unlock
  # The name "crypted" matches the name defined in disko.nix
  #
  # crypttabExtraOpts tells systemd-cryptsetup to try TPM2 first;
  # if it fails (e.g. PCRs changed), it prompts the user for the password as a fallback.
  boot.initrd.luks.devices."crypted" = {
    crypttabExtraOpts = [
      "tpm2-device=auto" # Automatically use the available TPM2
      "tpm2-pcrs=0+2+7" # PCRs to verify (firmware + Secure Boot state)
    ];
  };
}
