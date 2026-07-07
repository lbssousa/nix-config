# SELinux module — enables SELinux support Fedora-style.
#
# The linux_latest kernel already includes CONFIG_SECURITY_SELINUX=y and
# CONFIG_SECURITY_SELINUX_BOOTPARAM=y. NixOS manages the `lsm=` kernel
# parameter via `security.lsm`; adding "selinux" to that list enables the LSM.
#
# Initial mode: permissive.
# Unlike Fedora (enforcing + targeted), NixOS requires adapting the policy
# to cover paths under /nix/store. Until that's done, SELinux logs
# violations to the audit log without blocking them.
#
# To review violations:
#   ausearch -m avc -ts recent
#   audit2allow -a
{ lib, pkgs, ... }:

{
  # Inserts "selinux" at the front of the list of active LSMs.
  # NixOS turns security.lsm into `lsm=selinux:landlock:yama:bpf` —
  # never use `security=` directly in boot.kernelParams (it conflicts with lsm=).
  security.lsm = lib.mkBefore [ "selinux" ];

  # `selinux=1` enables the LSM when CONFIG_SECURITY_SELINUX_BOOTPARAM=y.
  # `enforcing=0` forces permissive mode; remove once the policy is validated for NixOS.
  boot.kernelParams = [
    "selinux=1"
    "enforcing=0"
  ];

  environment = {
    etc = {
      # Main config file — mirrors Fedora's /etc/selinux/config.
      "selinux/config".text = ''
        # SELinux configuration.
        # SELINUX: enforcing | permissive | disabled
        # Switch to enforcing after adapting file_contexts for /nix/store.
        SELINUX=permissive

        # SELINUXTYPE: name of the policy to load from /etc/selinux/<type>/.
        # Fedora uses "targeted" (a derived policy); NixOS uses "refpolicy"
        # (the base reference policy). The binary policy (policy.XX) needs
        # to be compiled with checkpolicy and loaded via load_policy before
        # switching to enforcing.
        SELINUXTYPE=refpolicy
      '';

      # Reference policy contexts (nixpkgs' selinux-refpolicy).
      # Note: this path is read-only (Nix store). To load additional
      # modules at runtime, use a writable directory under /persist/etc/selinux/.
      "selinux/refpolicy".source = "${pkgs.selinuxPackages.selinux-refpolicy}/etc/selinux/refpolicy";
    };

    # SELinux tools — equivalent to Fedora's policycoreutils group.
    systemPackages = with pkgs.selinuxPackages; [
      policycoreutils # load_policy, restorecon, chcon, seinfo, setsebool, getenforce
      setools # seinfo, sesearch, findcon (policy analysis)
      checkpolicy # policy compiler (.te + .fc + .if → policy.XX)
      semodule-utils # semodule, semodule_expand (module management)
    ];
  };
}
