# libfprint com suporte ao sensor Goodix 538d (fork lbssousa)
# Fork: https://github.com/lbssousa/libfprint (branch: goodix-538d-sigfm-gtls)
# Baseado no libfprint 1.94.10 com drivers Goodix TLS e matcher SIGFM (OpenCV).
#
# Drivers incluídos além do upstream:
#   - goodixtls511  – Goodix 5110
#   - goodixtls52xd – família Goodix 52xd
#   - goodixtls53xd – família Goodix 53xd (inclui 538d, USB 27c6:538d)
#
# O matcher SIGFM (sigfm/sigfm.cpp) usa OpenCV para capturar impressões de
# curta área onde o matcher minutiae padrão falha.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  meson,
  python3,
  ninja,
  gusb,
  pixman,
  glib,
  gobject-introspection,
  cairo,
  libgudev,
  udevCheckHook,
  gtk-doc,
  docbook-xsl-nons,
  docbook_xml_dtd_43,
  openssl,
  opencv4,
}:

stdenv.mkDerivation {
  pname = "libfprint-goodix";
  version = "1.94.10-unstable-2026-07-03";

  src = fetchFromGitHub {
    owner = "lbssousa";
    repo = "libfprint";
    rev = "02a5326fab3814730c1e8aab644c6972a72252fc";
    hash = "sha256-WLp5T5ERQM22Fv9DUDURNWlHHTVU4o9fWgfdWKguJjY=";
  };

  patches = [
    # Corrige use-after-free em goodix_tls_ready_image_handler: reseta o estado
    # de comando (ack/reply/callback) antes de marcar o SSM como falho em
    # dev_cancel, evitando que dados USB posteriores chamem o callback com
    # ponteiro para SSM já liberado.
    ./0001-fix-dev-cancel-reset-state-before-ssm-fail.patch
  ];

  postPatch = ''
    patchShebangs \
      tests/test-runner.sh \
      tests/unittest_inspector.py \
      tests/virtual-image.py \
      tests/umockdev-test.py \
      tests/test-generated-hwdb.sh \
      || true
  '';

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    gtk-doc
    docbook-xsl-nons
    docbook_xml_dtd_43
    gobject-introspection
    udevCheckHook
  ];

  buildInputs = [
    gusb
    pixman
    glib
    cairo
    libgudev
    openssl
    opencv4
  ];

  mesonFlags = [
    "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d"
    "-Ddrivers=default"
    "-Ddoc=false"
    "-Dgtk-examples=false"
    "-Dintrospection=true"
    "-Dudev_hwdb=disabled"
  ];

  nativeInstallCheckInputs = [
    (python3.withPackages (p: with p; [ pygobject3 ]))
  ];

  doCheck = false;
  doInstallCheck = false;

  meta = {
    homepage = "https://github.com/lbssousa/libfprint";
    description = "libfprint com drivers Goodix TLS e matcher SIGFM (fork lbssousa), suportando o sensor 538d (USB 27c6:538d)";
    license = lib.licenses.lgpl21Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
