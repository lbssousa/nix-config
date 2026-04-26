# Utilitário de impressora Epson para Linux
# Inclui o daemon ecbd (Epson Communication Bridge Daemon) e a interface gráfica.
# Compatível com a multifuncional Epson L4160 e outros modelos EcoTank/InkTank.
#
# Para atualizar o hash após uma nova versão:
#   nix-prefetch-url https://download3.ebz.epson.net/dsc/f/03/00/14/91/63/epson-printer-utility_1.1.2-1_amd64.deb
# ou
#   nix store prefetch-file --hash-type sha256 \
#     https://download3.ebz.epson.net/dsc/f/03/00/14/91/63/epson-printer-utility_1.1.2-1_amd64.deb
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
  version = "1.1.2";

  src = fetchurl {
    # Página de download: https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX
    url = "https://download3.ebz.epson.net/dsc/f/03/00/14/91/63/epson-printer-utility_${version}-1_amd64.deb";
    # Para obter o hash correto, execute:
    #   nix-prefetch-url <url>
    # e substitua o valor abaixo pelo resultado.
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
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
