# Builder compartilhado para todas as variantes do Brave Origin.
# Baseado em pkgs/by-name/br/brave/make-brave.nix do nixpkgs, adaptado para o
# flavor "origin" conforme proposto no PR https://github.com/NixOS/nixpkgs/pull/513143.
#
# Uso:
#   callPackage ./make-brave-origin.nix { } { pname, version, archives, channel }
{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  qt6,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libdrm,
  libkrb5,
  libuuid,
  libxkbcommon,
  libxshmfence,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  snappy,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  libxcb,
  zlib,

  # argumentos de linha de comando que sempre serão definidos
  commandLineArgs ? "",

  # Necessário para dispositivos de áudio USB.
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,

  # Para suporte a aceleração GPU via Wayland
  libGL,

  # Para aceleração de vídeo via VA-API
  libvaSupport ? stdenv.hostPlatform.isLinux,
  libva,
  enableVideoAcceleration ? libvaSupport,

  # Para suporte a Vulkan (desabilitado por padrão pois pode quebrar VA-API)
  vulkanSupport ? false,
  addDriverRunpath,
  enableVulkan ? vulkanSupport,
}:

{
  pname,
  version,
  # Mapa de sistema Nix → { url, hash }. Permite que arquivos por canal
  # omitam plataformas não publicadas pelo upstream.
  archives,
  # Canal de lançamento: "beta" ou "nightly".
  channel,
}:

let
  inherit (lib)
    optional
    optionals
    makeLibraryPath
    makeSearchPathOutput
    makeBinPath
    optionalString
    strings
    escapeShellArg
    ;

  channelSuffix = "-${channel}";

  # /opt/brave.com/brave-origin-<channel>/
  optName = "brave-origin${channelSuffix}";
  # Nome base para .desktop, xml e arquivos de ícone
  fileBase = "brave-origin${channelSuffix}";
  # App-id secundário do .desktop
  appId = "com.brave.Origin.${channel}";
  # Wrapper upstream dentro de /opt
  innerWrapper = fileBase;
  # Destino Exec= original nos .desktop (substituído pelo wrapper gerado pelo Nix)
  upstreamBin = fileBase;
  # Sufixo dos arquivos de ícone (e.g. "_beta", "_nightly")
  iconSuffix = "_${channel}";

  archive =
    assert lib.assertMsg (builtins.hasAttr stdenv.hostPlatform.system archives)
      "${pname} não está disponível para ${stdenv.hostPlatform.system}";
    archives.${stdenv.hostPlatform.system};

  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libx11
    libGL
    libxkbcommon
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxshmfence
    libxtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt6.qtbase
  ]
  ++ optional pulseSupport libpulseaudio
  ++ optional libvaSupport libva;

  rpath = makeLibraryPath deps + ":" + makeSearchPathOutput "lib" "lib64" deps;
  binpath = makeBinPath deps;

  enableFeatures =
    optionals enableVideoAcceleration [
      "AcceleratedVideoDecodeLinuxGL"
      "AcceleratedVideoEncoder"
    ]
    ++ optional enableVulkan "Vulkan";

  disableFeatures = [
    "OutdatedBuildDetector"
  ]
  ++ optionals enableVideoAcceleration [ "UseChromeOSDirectVideoDecoder" ];
in
stdenv.mkDerivation {
  inherit pname version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl { inherit (archive) url hash; };

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  doInstallCheck = stdenv.hostPlatform.isLinux;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    dpkg
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    glib
    gsettings-desktop-schemas
    gtk3
    gtk4
    adwaita-icon-theme
  ];

  installPhase = lib.optionalString stdenv.hostPlatform.isLinux ''
    runHook preInstall

    mkdir -p $out $out/bin

    cp -R usr/share $out
    cp -R opt/ $out/opt

    export BINARYWRAPPER=$out/opt/brave.com/${optName}/${innerWrapper}

    # Corrigir caminho do bash no wrapper
    substituteInPlace $BINARYWRAPPER \
        --replace-fail /bin/bash ${stdenv.shell} \
        --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

    ln -sf $BINARYWRAPPER $out/bin/${pname}

    for exe in $out/opt/brave.com/${optName}/{brave,chrome_crashpad_handler}; do
        patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath "${rpath}" $exe
    done

    # Corrigir caminhos nos arquivos .desktop
    substituteInPlace $out/share/applications/{${fileBase},${appId}}.desktop \
        --replace-fail /usr/bin/${upstreamBin} $out/bin/${pname}
    substituteInPlace $out/share/gnome-control-center/default-apps/${fileBase}.xml \
        --replace-fail /opt/brave.com $out/opt/brave.com
    substituteInPlace $out/opt/brave.com/${optName}/default-app-block \
        --replace-fail /opt/brave.com $out/opt/brave.com

    # Corrigir localização dos ícones
    icon_sizes=("16" "24" "32" "48" "64" "128" "256")

    for icon in ''${icon_sizes[*]}
    do
        mkdir -p $out/share/icons/hicolor/''${icon}x''${icon}/apps
        ln -s $out/opt/brave.com/${optName}/product_logo_''${icon}${iconSuffix}.png \
              $out/share/icons/hicolor/''${icon}x''${icon}/apps/${fileBase}.png
    done

    # Substituir xdg-settings e xdg-mime
    ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/brave.com/${optName}/xdg-settings
    ln -sf ${xdg-utils}/bin/xdg-mime $out/opt/brave.com/${optName}/xdg-mime

    runHook postInstall
  '';

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${binpath}
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          coreutils
        ]
      }
      --set CHROME_WRAPPER ${pname}
      ${optionalString (enableFeatures != [ ]) ''
        --add-flags "--enable-features=${strings.concatStringsSep "," enableFeatures}\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+,WaylandWindowDecorations --enable-wayland-ime=true}}"
      ''}
      ${optionalString (disableFeatures != [ ]) ''
        --add-flags "--disable-features=${strings.concatStringsSep "," disableFeatures}"
      ''}
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      ${optionalString vulkanSupport ''
        --prefix XDG_DATA_DIRS  : "${addDriverRunpath.driverLink}/share"
      ''}
      --add-flags ${escapeShellArg commandLineArgs}
    )
  '';

  installCheckPhase = ''
    $out/opt/brave.com/${optName}/brave --version
  '';

  meta = {
    homepage = "https://brave.com/origin/download-${channel}/";
    description = "Navegador Brave Origin focado em privacidade (canal ${channel})";
    changelog =
      "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP_ORIGIN.md#"
      + lib.replaceStrings [ "." ] [ "" ] version;
    longDescription = ''
      Brave Origin é uma variante simplificada do navegador Brave que remove a
      maioria das funcionalidades não relacionadas à privacidade (recompensas,
      carteira, IA, etc.), mantendo o núcleo de privacidade, bloqueio de
      anúncios e o motor de navegação baseado em Chromium.
    '';
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    maintainers = [ ];
    platforms = builtins.attrNames archives;
    mainProgram = pname;
  };
}
