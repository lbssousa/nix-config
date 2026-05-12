# IBus Compose shared module for all Home Manager users.
_: {
  xdg.configFile = {
    # Keep IBus Compose behavior aligned with the system locale table.
    "ibus/Compose".text = ''
      include "%L"
    '';
  };
}
