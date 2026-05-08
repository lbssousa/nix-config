# Módulo de redes Wi-Fi: Configuração de redes Wi-Fi pessoais via NetworkManager.
# A senha e os SSIDs das redes são gerenciados pelo sops-nix e nunca ficam em
# texto simples no repositório.
{ config, inputs, ... }:

{
  sops = {
    # Chave age para descriptografar os segredos durante a ativação do sistema (boot).
    # O caminho deve ser de sistema (não home de usuário), pois a descriptografia ocorre como root.
    age.keyFile = "/persist/etc/sops/age/keys.txt";

    secrets.wifi_password = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "wifi.password";
    };
    secrets.wifi_ssid_5g = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "wifi.ssid_5g";
    };
    secrets.wifi_ssid_2_4g = {
      sopsFile = inputs.nix-secrets + "/secrets.yaml";
      key = "wifi.ssid_2_4g";
    };

    # Perfil NetworkManager — banda 5 GHz
    templates."home-wifi-5g.nmconnection" = {
      content = ''
        [connection]
        id=${config.sops.placeholder.wifi_ssid_5g}
        uuid=16c9c8f0-5e66-4368-8d26-95b2c6ff810d
        type=wifi
        autoconnect=true

        [wifi]
        mode=infrastructure
        ssid=${config.sops.placeholder.wifi_ssid_5g}

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
        id=${config.sops.placeholder.wifi_ssid_2_4g}
        uuid=cd867d94-2953-4c4b-87fd-ace0cdacc886
        type=wifi
        autoconnect=true

        [wifi]
        mode=infrastructure
        ssid=${config.sops.placeholder.wifi_ssid_2_4g}

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
