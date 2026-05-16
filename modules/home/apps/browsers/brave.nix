# Módulo de usuário: Brave Browser via nixpkgs-unstable com extensão KeePassXC-Browser
{
  pkgs,
  inputs,
  ...
}:

let
  # O keepassxc do nixpkgs instala o manifesto de native messaging apenas para
  # Mozilla (lib/mozilla/native-messaging-hosts/). Para navegadores Chromium, o
  # HM espera pacotes com o manifesto em etc/chromium/native-messaging-hosts/.
  # Aqui geramos esse manifesto apontando para o binário keepassxc-proxy.
  keepassxcNativeMessagingChromium = pkgs.writeTextFile {
    name = "keepassxc-native-messaging-chromium";
    destination = "/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json";
    text = builtins.toJSON {
      name = "org.keepassxc.keepassxc_browser";
      description = "KeePassXC integration with native messaging support";
      path = "${pkgs.keepassxc}/bin/keepassxc-proxy";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
      ];
    };
  };
in

{
  programs.brave = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.brave;
    extensions = [
      { id = "oboonakemofpalcgghocfoadofidjkkk"; } # KeePassXC-Browser
    ];
    nativeMessagingHosts = [ keepassxcNativeMessagingChromium ];
  };
}
