{ inputs, ... }:
{
  config.dendritic.hosts = {
    barbudus = {
      system = "x86_64-linux";
      extraNixosModules = [
        inputs.lanzaboote.nixosModules.lanzaboote
      ];
    };

    bigodon = {
      system = "x86_64-linux";
      extraNixosModules = [ ];
    };
  };
}
