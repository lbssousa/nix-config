# Shells module: Bash, Fish and Zsh (Fish as default)
{ pkgs, ... }:

{
  # Install all three shells
  environment.systemPackages = with pkgs; [
    bash
    fish
    zsh
    # Zsh utilities
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    # Starship prompt (cross-shell, for users with no specific config)
    starship
  ];

  # Enable Bash (already default, but we ensure config)
  programs = {
    bash = {
      # Extra completions for Bash
      completion.enable = true;
    };

    # Enable Fish shell
    fish = {
      enable = true;
      # Additional completions
      vendor = {
        completions.enable = true;
        config.enable = true;
        functions.enable = true;
      };
    };

    # Enable Zsh as the system's default shell
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      # histFile and histSize are configured per user via home-manager (home.nix)
    };
  };

  # Set Fish as the default shell for new users
  users.defaultUserShell = pkgs.fish;

  # Add shells to /etc/shells
  environment.shells = with pkgs; [
    bash
    fish
    zsh
  ];
}
