# Módulo de redes Wi-Fi: Configuração de redes Wi-Fi pessoais via NetworkManager.
# A senha das redes é gerenciada pelo sops-nix e nunca fica em texto simples
# no repositório.
{ config, ... }:

{
  # Chave age para descriptografar os segredos durante a ativação do sistema (boot).
  # O caminho deve ser de sistema (não home de usuário), pois a descriptografia ocorre como root.
  sops.age.keyFile = "/persist/etc/sops/age/keys.txt";

  sops.secrets.wifi_password = {
    sopsFile = ../../../secrets/wifi.yaml;
  };

  # Perfil NetworkManager — "HOME_WIFI_5G" (banda 5 GHz)
  sops.templates."HOME_WIFI_5G.nmconnection" = {
    content = ''
      [connection]
      id=HOME_WIFI_5G
      uuid=16c9c8f0-5e66-4368-8d26-95b2c6ff810d
      type=wifi
      autoconnect=true

      [wifi]
      mode=infrastructure
      ssid=HOME_WIFI_5G

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
    path = "/etc/NetworkManager/system-connections/HOME_WIFI_5G.nmconnection";
    mode = "0600";
    owner = "root";
    group = "root";
  };

  # Perfil NetworkManager — "HOME_WIFI_2_4G" (banda 2,4 GHz)
  sops.templates."HOME_WIFI_2_4G.nmconnection" = {
    content = ''
      [connection]
      id=HOME_WIFI_2_4G
      uuid=cd867d94-2953-4c4b-87fd-ace0cdacc886
      type=wifi
      autoconnect=true

      [wifi]
      mode=infrastructure
      ssid=HOME_WIFI_2_4G

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
    path = "/etc/NetworkManager/system-connections/HOME_WIFI_2_4G.nmconnection";
    mode = "0600";
    owner = "root";
    group = "root";
  };
}
