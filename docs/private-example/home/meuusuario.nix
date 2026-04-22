# Configuração Home Manager pessoal para "meuusuario".
# Importe este arquivo em nixos/users.nix via home-manager.users.meuusuario.imports.
_:

{
  home = {
    username = "meuusuario";
    homeDirectory = "/home/meuusuario";
    stateVersion = "25.05"; # Deve coincidir com o sistema
  };

  # Sobreponha/complemente as configurações do home.nix público
  programs.git = {
    userName = "Meu Nome Completo";
    userEmail = "meu@email.com";
    # Chave GPG de assinatura (opcional):
    # signing.key = "ABCDEF1234567890";
    # signing.signByDefault = true;
  };

  # Adicione configurações personalizadas adicionais conforme necessário.
  # Todos os módulos do home-manager estão disponíveis aqui.
}
