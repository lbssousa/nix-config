# OBSOLETO: substituído pelo módulo de sistema modules/system/desktop/desktop.nix,
# que usa systemd.user.tmpfiles.rules para criar este arquivo para todos os
# usuários (inclusive os que não usam home-manager).
# Este arquivo pode ser removido quando não houver mais referência a ele.
_: {
  xdg.configFile = {
    # Keep IBus Compose behavior aligned with the system locale table.
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
