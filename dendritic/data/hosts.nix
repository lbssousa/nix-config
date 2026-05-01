{ inputs, ... }:
{
  config.dendritic.hosts = {
    barbudus = {
      system = "x86_64-linux";
      defaultDesktop = "plasma";
      extraNixosModules = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];
    };

    bigodon = {
      system = "x86_64-linux";
      defaultDesktop = "plasma";
      extraNixosModules = [ ];
    };
  };
}
