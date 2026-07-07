# Epson printer utility for Linux
# Includes the ecbd daemon (Epson Communication Bridge Daemon) and the GUI.
# Compatible with the Epson L4160 all-in-one and other EcoTank/InkTank models.
#
# To update to a new version:
# 1. Query the Epson Download Center API for the latest URL:
#      curl -s -A "Firefox" \
#        "https://download-center.epson.com/api/v1/modules/?device_id=L3250%20Series&os=LX&region=US&language=en" \
#        | jq '.items[] | select(.url | test("printer-utility.*_amd64\\.deb$")) | {version, url}'
#    NOTE: the "Firefox" User-Agent is mandatory to get past Epson's Akamai
#    WAF. Strings containing "Mozilla" are blocked; use only "Firefox".
# 2. Get the SHA256 hash with:
#      nix-prefetch-url <url>
#    or:
#      nix store prefetch-file --hash-type sha256 <url>
# 3. Update the `version`, `url` and `hash` fields below.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  file,
  cups,
  qt5,
  libusb1,
}:

stdenv.mkDerivation rec {
  pname = "epson-printer-utility";
  version = "1.2.2";

  src = fetchurl {
    # URL obtained via the Epson Download Center API (os=LX, device_id=L3250 Series).
    # Requires the "Firefox" User-Agent to get past the Akamai WAF (strings
    # with "Mozilla" are blocked). The numeric path segment is
    # version-specific; see the steps in this file's header to get the URL
    # for a new version.
    url = "https://download3.ebz.epson.net/dsc/f/03/00/16/74/30/9067c71049e81fbbee48a4695c5c0acf308b9f18/epson-printer-utility_${version}-1_amd64.deb";
    # "Firefox" User-Agent required for Epson's Akamai WAF (all "Mozilla/..."
    # variants are explicitly blocked; use only "Firefox").
    curlOptsList = [
      "--user-agent"
      "Firefox"
    ];
    hash = "sha256-8OG2Hva+7FGA9s8x/7uH9IMbgRgez6zl5z1XA32RRJI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    file
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    cups
    qt5.qtbase
    libusb1
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    dpkg-deb --extract $src .
  '';

  installPhase = ''
    runHook preInstall

    # Install the main GUI binary
    install -Dm755 opt/epson-printer-utility/bin/epson-printer-utility \
      $out/bin/epson-printer-utility

    # Install the ecbd daemon and the CUPS backend
    install -Dm755 usr/lib/epson-backend/ecbd $out/lib/epson-backend/ecbd
    install -Dm755 usr/lib/cups/backend/ecblp $out/lib/cups/backend/ecblp

    # Install the daemon's config and support files
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

    # Install resources (images and translations)
    mkdir -p $out/share/epson-printer-utility
    cp -r opt/epson-printer-utility/resource $out/share/epson-printer-utility/resource

    # Install the icon in the standard XDG directory
    install -Dm644 opt/epson-printer-utility/resource/Images/AppIcon.png \
      $out/share/icons/hicolor/256x256/apps/epson-printer-utility.png

    # Install and fix the .desktop file (DEB paths point to /opt)
    install -Dm644 opt/epson-printer-utility/epson-printer-utility.desktop \
      $out/share/applications/epson-printer-utility.desktop
    sed -i \
      -e 's|^Exec=.*|Exec=epson-printer-utility|' \
      -e 's|^Icon=.*|Icon=epson-printer-utility|' \
      $out/share/applications/epson-printer-utility.desktop

    # Install the udev rules
    install -Dm644 opt/epson-printer-utility/rules/79-udev-epson.rules \
      $out/lib/udev/rules.d/79-udev-epson.rules

    # Fix hardcoded absolute paths from the original .deb package
    # (/usr/lib/epson-backend and /opt/epson-printer-utility) in all
    # installed text files (ecbd.conf, scripts, rc.d, etc.), replacing
    # them with the correct Nix store paths.
    find "$out/lib/epson-backend" -type f | while read -r f; do
      if file --mime-type "$f" | grep -q "text/"; then
        sed -i \
          -e "s|/usr/lib/epson-backend|$out/lib/epson-backend|g" \
          -e "s|/opt/epson-printer-utility|$out/share/epson-printer-utility|g" \
          "$f"
      fi
    done

    # Install the documentation
    if [ -d usr/share/doc ]; then
      mkdir -p $out/share/doc/epson-printer-utility
      cp -r usr/share/doc/. $out/share/doc/epson-printer-utility/
    fi

    runHook postInstall
  '';

  meta = {
    homepage = "https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX";
    description = "Epson Printer Utility — maintenance tool for Epson inkjet printers";
    longDescription = ''
      Epson Printer Utility provides a GUI to monitor ink levels, run
      printhead cleaning and other maintenance functions on Epson inkjet
      printers (L4160, L3150, L3110 and other models).

      Includes the ecbd daemon (Epson Communication Bridge Daemon) required
      for two-way communication between the utility and the printer.
    '';
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
