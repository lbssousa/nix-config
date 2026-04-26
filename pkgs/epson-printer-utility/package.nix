# Utilitário de impressora Epson para Linux
# Inclui o daemon ecbd (Epson Communication Bridge Daemon) e a interface gráfica.
# Compatível com a multifuncional Epson L4160 e outros modelos EcoTank/InkTank.
#
# Para atualizar para uma nova versão:
# 1. Localize a URL de download em: https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX
# 2. Obtenha o hash SHA256 com:
#      nix-prefetch-url <url>
#    ou:
#      nix store prefetch-file --hash-type sha256 <url>
# 3. Atualize os campos `url` e `hash` abaixo.
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
    # Página de download: https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX
    # FIXME: O segmento de caminho abaixo (/03/00/.../  ) é específico de cada versão
    # no CDN da Epson. Verifique a URL correta para a versão ${version} na página acima
    # e atualize este campo antes de fazer o build.
    url = "https://download3.ebz.epson.net/dsc/f/03/00/16/08/67/epson-printer-utility_${version}-1_amd64.deb";
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
