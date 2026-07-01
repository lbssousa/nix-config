# Módulo de usuário: Brave Browser — navegador alternativo (padrão: Firefox)
{ pkgs, ... }:

{
  programs.brave = {
    enable = true;
    package = pkgs.brave;
    extensions = [
      { id = "oboonakemofpalcgghocfoadofidjkkk"; } # KeePassXC-Browser
    ];
  };
}
