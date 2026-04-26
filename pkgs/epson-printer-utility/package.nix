# Utilitário de impressora Epson para Linux
# Inclui o daemon ecbd (Epson Communication Bridge Daemon) e a interface gráfica.
# Compatível com a multifuncional Epson L4160 e outros modelos EcoTank/InkTank.
#
# Para atualizar para uma nova versão:
# 1. Consulte a API do Epson Download Center para obter a URL mais recente:
#      curl -s -A "Firefox" \
#        "https://download-center.epson.com/api/v1/modules/?device_id=L3250%20Series&os=LX&region=US&language=en" \
#        | jq '.items[] | select(.url | test("printer-utility.*_amd64\\.deb$")) | {version, url}'
#    NOTA: o User-Agent "Firefox" é obrigatório para contornar o WAF Akamai da Epson.
#    Strings contendo "Mozilla" são bloqueadas; use apenas "Firefox".
# 2. Obtenha o hash SHA256 com:
#      nix-prefetch-url <url>
#    ou:
#      nix store prefetch-file --hash-type sha256 <url>
# 3. Atualize os campos `version`, `url` e `hash` abaixo.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  cups,
  gtk3,
  glib,
  libusb1,
}:

stdenv.mkDerivation rec {
  pname = "epson-printer-utility";
  version = "1.2.2";

  src = fetchurl {
    # URL obtida via API do Epson Download Center (os=LX, device_id=L3250 Series).
    # Requer User-Agent "Firefox" para contornar o WAF Akamai (strings com "Mozilla"
    # são bloqueadas). O segmento de caminho numérico é específico de cada versão;
    # consulte os passos no cabeçalho deste arquivo para obter a URL da nova versão.
    url = "https://download3.ebz.epson.net/dsc/f/03/00/16/74/30/9067c71049e81fbbee48a4695c5c0acf308b9f18/epson-printer-utility_${version}-1_amd64.deb";
    # User-Agent "Firefox" necessário para o WAF Akamai da Epson (todas as variantes
    # de "Mozilla/..." são explicitamente bloqueadas; use apenas "Firefox").
    curlOptsList = [
      "--user-agent"
      "Firefox"
    ];
    hash = "sha256-8OG2Hva+7FGA9s8x/7uH9IMbgRgez6zl5z1XA32RRJI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    cups
    gtk3
    glib
    libusb1
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    dpkg-deb --extract $src .
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/sbin $out/lib $out/share

    # Instala os executáveis
    install -Dm755 usr/bin/epson-printer-utility $out/bin/epson-printer-utility
    install -Dm755 usr/sbin/ecbd $out/sbin/ecbd

    # Copia as bibliotecas
    if [ -d usr/lib ]; then
      cp -r usr/lib/. $out/lib/
    fi

    # Copia dados compartilhados (ícones, .desktop, traduções)
    if [ -d usr/share ]; then
      cp -r usr/share/. $out/share/
    fi

    runHook postInstall
  '';

  meta = {
    homepage = "https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX";
    description = "Epson Printer Utility — ferramenta de manutenção para impressoras Epson inkjet";
    longDescription = ''
      O Epson Printer Utility fornece uma interface gráfica para monitorar o nível
      de tinta, executar limpeza dos cabeçotes de impressão e outras funções de
      manutenção em impressoras inkjet Epson (L4160, L3150, L3110 e outros modelos).

      Inclui o daemon ecbd (Epson Communication Bridge Daemon) necessário para a
      comunicação bidirecional entre o utilitário e a impressora.
    '';
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
