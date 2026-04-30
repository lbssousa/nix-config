{ inputs, ... }:
let
  # Hosts and their system architectures
  allHosts = {
    barbudus = "x86_64-linux";
    bigodon = "x86_64-linux";
  };

  # Helper to build a standalone Home Manager configuration for a given user/host
  mkHome =
    username: system: desktop: extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {
        inherit inputs desktop;
      };
      modules = [
        # Global Home Manager configuration (common to all users)
        ../home/common.nix
        # User identity
        {
          home.username = username;
          home.homeDirectory = "/home/${username}";
        }
      ]
      ++ extraModules;
    };

  # Generate homeConfigurations entries for a user across all hosts
  mkHomeAllHosts =
    username: extraModules:
    inputs.nixpkgs.lib.mapAttrs' (hostname: system: {
      name = "${username}@${hostname}";
      value = mkHome username system "plasma" extraModules;
    }) allHosts;

  mkHomeAllHostsDesktop =
    username: desktop: extraModules:
    inputs.nixpkgs.lib.mapAttrs' (hostname: system: {
      name = "${username}@${hostname}-${desktop}";
      value = mkHome username system desktop extraModules;
    }) allHosts;
in
{
  # Home Manager configurations (user-level — run with: home-manager switch --flake .#<user>@<host>[-<desktop>])
  # abutre: configuração personalizada (powerlevel10k, git SSH signing, Bitwarden)
  flake.homeConfigurations =
    mkHomeAllHosts abutre [ ../home/users/abutre/home.nix ]
    // mkHomeAllHostsDesktop abutre "gnome" [ ../home/users/abutre/home.nix ]
    // mkHomeAllHostsDesktop abutre "plasma" [ ../home/users/abutre/home.nix ]
    // mkHomeAllHosts surubi [ ]
    // mkHomeAllHosts coruja [ ]
    // mkHomeAllHosts camelo [ ]
    // mkHomeAllHosts cavalo [ ]
    // mkHomeAllHosts macaco [ ];
}
