# Módulo de redes Wi-Fi: Definição declarativa de redes Wi-Fi via NetworkManager
#
# Adicione suas redes Wi-Fi como atributos de networking.networkmanager.ensureProfiles.profiles.
# Cada perfil corresponde a uma conexão do NetworkManager (formato keyfile).
#
# Exemplo de uso:
#
#   networking.networkmanager.ensureProfiles.profiles = {
#     "MinhaRedeCasa" = {
#       connection = {
#         id = "MinhaRedeCasa";
#         type = "wifi";
#       };
#       wifi = {
#         mode = "infrastructure";
#         ssid = "MinhaRedeCasa";
#       };
#       wifi-security = {
#         auth-alg = "open";
#         key-mgmt = "wpa-psk";
#         psk = "SenhaAqui";
#       };
#       ipv4.method = "auto";
#       ipv6 = {
#         addr-gen-mode = "default";
#         method = "auto";
#       };
#     };
#   };
#
# Nota: o campo psk aceita tanto a senha em texto simples quanto o hash PBKDF2
# gerado por wpa_passphrase (64 dígitos hexadecimais), que é irreversível e mais
# seguro para armazenar em repositórios:
#
#   nix-shell -p wpa_supplicant --run "wpa_passphrase MinhaRede SenhaAqui"
#
# O valor do campo "psk=" (sem aspas) na saída do wpa_passphrase é o hash a usar.
_: {
  # Adicione os perfis Wi-Fi abaixo via networking.networkmanager.ensureProfiles.profiles.
  # Consulte os comentários no início deste arquivo para exemplos e instruções.
}
