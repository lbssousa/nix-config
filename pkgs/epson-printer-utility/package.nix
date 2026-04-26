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

    # Instala o binário principal da GUI
    install -Dm755 opt/epson-printer-utility/bin/epson-printer-utility \
      $out/bin/epson-printer-utility

    # Instala o daemon ecbd e o backend CUPS
    install -Dm755 usr/lib/epson-backend/ecbd $out/lib/epson-backend/ecbd
    install -Dm755 usr/lib/cups/backend/ecblp $out/lib/cups/backend/ecblp

    # Instala configuração e arquivos de suporte do daemon
    for f in ecbd.conf ecbd.pp ecbd.service ecblp.pp epson_pol.pp; do
      if [ -f usr/lib/epson-backend/$f ]; then
        install -Dm644 usr/lib/epson-backend/$f $out/lib/epson-backend/$f
      fi
    done
    if [ -d usr/lib/epson-backend/rc.d ]; then
      cp -r usr/lib/epson-backend/rc.d $out/lib/epson-backend/rc.d
    fi
    if [ -d usr/lib/epson-backend/scripts ]; then
      cp -r usr/lib/epson-backend/scripts $out/lib/epson-backend/scripts
    fi

    # Instala recursos (imagens e traduções)
    mkdir -p $out/share/epson-printer-utility
    cp -r opt/epson-printer-utility/resource $out/share/epson-printer-utility/resource

    # Instala o arquivo .desktop
    install -Dm644 opt/epson-printer-utility/epson-printer-utility.desktop \
      $out/share/applications/epson-printer-utility.desktop

    # Instala as regras udev
    install -Dm644 opt/epson-printer-utility/rules/79-udev-epson.rules \
      $out/lib/udev/rules.d/79-udev-epson.rules

    # Instala a documentação
    if [ -d usr/share/doc ]; then
      cp -r usr/share/doc/. $out/share/doc/epson-printer-utility/
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
