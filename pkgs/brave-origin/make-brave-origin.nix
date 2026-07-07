# Shared builder for all Brave Origin variants.
# Based on nixpkgs' pkgs/by-name/br/brave/make-brave.nix, adapted for the
# "origin" flavor as proposed in PR https://github.com/NixOS/nixpkgs/pull/513143.
#
# Usage:
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

  # command-line arguments that will always be set
  commandLineArgs ? "",

  # Needed for USB audio devices.
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,

  # For GPU acceleration support via Wayland
  libGL,

  # For video acceleration via VA-API
  libvaSupport ? stdenv.hostPlatform.isLinux,
  libva,
  enableVideoAcceleration ? libvaSupport,

  # For Vulkan support (disabled by default since it can break VA-API)
  vulkanSupport ? false,
  addDriverRunpath,
  enableVulkan ? vulkanSupport,
}:

{
  pname,
  version,
  # Map of Nix system → { url, hash }. Lets per-channel files omit
  # platforms not published upstream.
  archives,
  # Release channel: "beta" or "nightly".
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
  # Base name for the .desktop, xml and icon files
  fileBase = "brave-origin${channelSuffix}";
  # Secondary app-id from the .desktop
  appId = "com.brave.Origin.${channel}";
  # Upstream wrapper inside /opt
  innerWrapper = fileBase;
  # Original Exec= target in the .desktop files (replaced by the Nix-generated wrapper)
  upstreamBin = fileBase;
  # Icon file suffix (e.g. "_beta", "_nightly")
  iconSuffix = "_${channel}";

  archive =
    assert lib.assertMsg (builtins.hasAttr stdenv.hostPlatform.system archives)
      "${pname} is not available for ${stdenv.hostPlatform.system}";
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

    # Fix the bash path in the wrapper
    substituteInPlace $BINARYWRAPPER \
        --replace-fail /bin/bash ${stdenv.shell} \
        --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

    ln -sf $BINARYWRAPPER $out/bin/${pname}

    for exe in $out/opt/brave.com/${optName}/{brave,chrome_crashpad_handler}; do
        patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath "${rpath}" $exe
    done

    # Fix paths in the .desktop files
    substituteInPlace $out/share/applications/{${fileBase},${appId}}.desktop \
        --replace-fail /usr/bin/${upstreamBin} $out/bin/${pname}
    substituteInPlace $out/share/gnome-control-center/default-apps/${fileBase}.xml \
        --replace-fail /opt/brave.com $out/opt/brave.com
    substituteInPlace $out/opt/brave.com/${optName}/default-app-block \
        --replace-fail /opt/brave.com $out/opt/brave.com

    # Fix icon locations
    icon_sizes=("16" "24" "32" "48" "64" "128" "256")

    for icon in ''${icon_sizes[*]}
    do
        mkdir -p $out/share/icons/hicolor/''${icon}x''${icon}/apps
        ln -s $out/opt/brave.com/${optName}/product_logo_''${icon}${iconSuffix}.png \
              $out/share/icons/hicolor/''${icon}x''${icon}/apps/${fileBase}.png
    done

    # Replace xdg-settings and xdg-mime
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
    description = "Privacy-focused Brave Origin browser (${channel} channel)";
    changelog =
      "https://github.com/brave/brave-browser/blob/master/CHANGELOG_DESKTOP_ORIGIN.md#"
      + lib.replaceStrings [ "." ] [ "" ] version;
    longDescription = ''
      Brave Origin is a simplified variant of the Brave browser that removes
      most non-privacy-related features (rewards, wallet, AI, etc.), while
      keeping the privacy core, ad blocking and the Chromium-based browsing engine.
    '';
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    maintainers = [ ];
    platforms = builtins.attrNames archives;
    mainProgram = pname;
  };
}
