# Powerlevel10k prompt, exclusive to the abutre user (Zsh only — the other
# shells keep the shared Starship "Catppuccin Powerline" prompt from
# home/common.nix). Uses the "rainbow" preset bundled with the package
# instead of a hand-authored config; run `p10k configure` interactively to
# generate a personal ~/.p10k.zsh and adjust programs.zsh.initContent below
# to source it instead.
{ pkgs, lib, ... }:

{
  # Starship and Powerlevel10k both hook the prompt — only one can render it.
  programs.starship.enableZshIntegration = false;

  programs.zsh = {
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = lib.mkMerge [
      # Instant prompt must be the first thing that runs in .zshrc — before
      # any command that could produce output — so it has to sit ahead of
      # every other init block (path setup starts at order 500).
      (lib.mkOrder 50 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      # After the theme is sourced (plugins source at order 900).
      (lib.mkOrder 950 ''
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/config/p10k-rainbow.zsh
      '')
    ];
  };
}
