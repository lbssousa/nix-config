# Packages scripts/import-gpg-yubikey.sh as a plain `yubikey-gpg-import`
# command for an already-installed system. Reads that file directly —
# single source of truth, no duplicated logic. See its header comment for
# what it does and why it also exists unpackaged (it needs to run on a live
# NixOS ISO too, before this flake's packages are buildable).
{
  lib,
  writeShellApplication,
  gnupg,
  curl,
  usbutils,
}:

writeShellApplication {
  name = "yubikey-gpg-import";

  runtimeInputs = [
    gnupg
    curl
    usbutils
  ];

  text = lib.removePrefix "#!/usr/bin/env bash\n" (
    builtins.readFile ../../scripts/import-gpg-yubikey.sh
  );
}
