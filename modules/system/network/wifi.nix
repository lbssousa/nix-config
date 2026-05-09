# Módulo de redes Wi-Fi: Configuração de redes Wi-Fi pessoais via NetworkManager.
# A senha é gerenciada pelo sops-nix; os SSIDs vêm de inputs.nix-secrets (não são segredos).
{ config, inputs, ... }:

let
  ssid5g = inputs.nix-secrets.wifi.ssid5g;
  ssid24g = inputs.nix-secrets.wifi.ssid24g;
in

{
  sops = {
    # Chave age para descriptografar os segredos durante a ativação do sistema (boot).
    # O caminho deve ser de sistema (não home de usuário), pois a descriptografia ocorre como root.
    age.keyFile = "/persist/etc/sops/age/keys.txt";

    secrets.wifi_password = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "wifi/password";
    };

    # Perfil NetworkManager — banda 5 GHz
    templates."home-wifi-5g.nmconnection" = {
      content = ''
        [connection]
        id=${ssid5g}
        uuid=16c9c8f0-5e66-4368-8d26-95b2c6ff810d
        type=wifi
        autoconnect=true

        [wifi]
        mode=infrastructure
        ssid=${ssid5g}

        [wifi-security]
        auth-alg=open
        key-mgmt=wpa-psk
        psk=${config.sops.placeholder.wifi_password}

        [ipv4]
        method=auto

        [ipv6]
        addr-gen-mode=default
        method=auto
      '';
      path = "/etc/NetworkManager/system-connections/home-wifi-5g.nmconnection";
      mode = "0600";
      owner = "root";
      group = "root";
    };

    # Perfil NetworkManager — banda 2,4 GHz
    templates."home-wifi-2.4g.nmconnection" = {
      content = ''
        [connection]
        id=${ssid24g}
        uuid=cd867d94-2953-4c4b-87fd-ace0cdacc886
        type=wifi
        autoconnect=true

        [wifi]
        mode=infrastructure
        ssid=${ssid24g}

        [wifi-security]
        auth-alg=open
        key-mgmt=wpa-psk
        psk=${config.sops.placeholder.wifi_password}

        [ipv4]
        method=auto

        [ipv6]
        addr-gen-mode=default
        method=auto
      '';
      path = "/etc/NetworkManager/system-connections/home-wifi-2.4g.nmconnection";
      mode = "0600";
      owner = "root";
      group = "root";
    };
  };
}
