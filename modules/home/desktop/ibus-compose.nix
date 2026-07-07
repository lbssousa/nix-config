# DEPRECATED: replaced by the system module modules/system/desktop/desktop.nix,
# which uses systemd.user.tmpfiles.rules to create this file for all users
# (including those not using home-manager).
# This file can be removed once nothing references it anymore.
_: {
  xdg.configFile = {
    # Keep IBus Compose behavior aligned with the system locale table.
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
