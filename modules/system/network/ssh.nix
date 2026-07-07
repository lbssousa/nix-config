# SSH module: OpenSSH server with keys in /persist
{ lib, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    # Server keys stored in /persist to survive rollback
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };
}
