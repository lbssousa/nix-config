# fprintd 1.94.5 compilado contra o fork lbssousa do libfprint (1.94.10).
# A versão 1.94.5 requer libfprint >= 1.94.9, compatível com o novo fork.
{
  lib,
  stdenv,
  fetchFromGitLab,
  pkg-config,
  gobject-introspection,
  meson,
  ninja,
  perl,
  gettext,
  gtk-doc,
  libxslt,
  docbook-xsl-nons,
  docbook_xml_dtd_412,
  glib,
  dbus,
  polkit,
  nss,
  pam,
  systemdLibs,
  libfprint-goodix,
  python3,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fprintd-goodix";
  version = "1.94.5";
  outputs = [ "out" ];

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "libfprint";
    repo = "fprintd";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aGIz50S0zfE3rV6QJp8iQz3uUVn8WAL68KU70j8GyOU=";
  };

  postPatch = ''
    patchShebangs \
      po/check-translations.sh \
      tests/unittest_inspector.py \
      || true
  '';

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
    perl
    gettext
    gtk-doc
    python3
    libxslt
    dbus
    docbook-xsl-nons
    docbook_xml_dtd_412
  ];

  buildInputs = [
    glib
    polkit
    nss
    pam
    systemdLibs
    libfprint-goodix
    gobject-introspection
  ];

  mesonFlags = [
    "-Dgtk_doc=false"
    "-Dpam_modules_dir=${placeholder "out"}/lib/security"
    "-Dsysconfdir=${placeholder "out"}/etc"
    "-Ddbus_service_dir=${placeholder "out"}/share/dbus-1/system-services"
    "-Dsystemd_system_unit_dir=${placeholder "out"}/lib/systemd/system"
  ];

  env = {
    PKG_CONFIG_POLKIT_GOBJECT_1_POLICYDIR = "${placeholder "out"}/share/polkit-1/actions";
    PKG_CONFIG_DBUS_1_INTERFACES_DIR = "${placeholder "out"}/share/dbus-1/interfaces";
    PKG_CONFIG_DBUS_1_DATADIR = "${placeholder "out"}/share";
  };

  doCheck = false;

  meta = {
    homepage = "https://fprint.freedesktop.org/";
    description = "fprintd ${finalAttrs.version} com suporte ao sensor Goodix via fork lbssousa do libfprint";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
})
