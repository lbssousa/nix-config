# IBus Compose shared module for all Home Manager users.
{
  lib,
  osConfig,
  ...
}:

let
  isGnome = osConfig.my.desktop.environment == "gnome";
in
{
  xdg.configFile = lib.mkIf isGnome {
    # Keep IBus Compose behavior aligned with the system locale table.
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
