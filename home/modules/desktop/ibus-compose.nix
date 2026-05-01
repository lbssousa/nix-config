# IBus Compose shared module for all Home Manager users.
{ lib, desktop ? "gnome", ... }:

let
  isGnome = desktop == "gnome";
in
{
  xdg.configFile = lib.mkIf isGnome {
    # Keep IBus Compose behavior aligned with the system locale table.
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
