# User module: Zed Editor with LSPs and extensions
{
  pkgs,
  ...
}:

{
  programs."zed-editor" = {
    enable = true;
    # Note: "gregorio" is installed locally via xdg.dataFile + activation below;
    # it must not be listed here, or Zed will try to install it from the
    # marketplace and wipe the installed/gregorio/ directory.
    extensions = [
      "nix"
      "latex"
    ];
    extraPackages = with pkgs; [
      direnv
      nil
      nixd
      texlab
      ltex-ls
      grelint
      gregorio-lsp
    ];
    userSettings = {
      theme = {
        mode = "dark";
        dark = "One Dark";
        light = "One Light";
      };
      load_direnv = "direct";
      soft_wrap = "preferred_line_length";
      preferred_line_length = 80;
      wrap_guides = [ 80 ];
      autosave = {
        after_delay = {
          milliseconds = 1000;
        };
      };
      vim_mode = false;
      hour_format = "hour24";
      ui_font_size = 20;
      agent_ui_font_size = 20;
      buffer_font_family = "ZedMono Nerd Font Mono";
      buffer_font_size = 22;
      agent_buffer_font_size = 20;
      terminal = {
        font_family = "JetBrainsMono Nerd Font Mono";
        font_size = 18;
      };
      lsp = {
        nil.binary.path = "${pkgs.nil}/bin/nil";
        nixd.binary.path = "${pkgs.nixd}/bin/nixd";
        texlab.binary.path = "${pkgs.texlab}/bin/texlab";
        "ltex-ls".binary.path = "${pkgs.ltex-ls}/bin/ltex-ls";
      };
    };
  };
}
