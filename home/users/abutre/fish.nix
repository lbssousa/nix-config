# Fish plugins exclusive to the abutre user, including fish-ai ("ai"),
# which uses the OPENAI_API_KEY variable. Other users use Fish without
# plugins (see home/common.nix).
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  sops.secrets."openai-api-key" = {
    sopsFile = inputs.nix-secrets + "/secrets.yaml";
    key = "abutre/openai_api_key";
  };

  # NOTE: fishPlugins.async-prompt was removed on purpose — it hijacks
  # fish_prompt/fish_right_prompt to render them via a backgrounded `fish -c`
  # job (spawned with `&` + `disown`). Starship already computes its prompt
  # asynchronously on its own, so the plugin is redundant; here it also broke
  # the custom starship theme outright ("disown: no suitable jobs" on every
  # prompt, background job dying immediately), leaving fish_prompt stuck on
  # a plain, uncolored fallback instead of the Catppuccin preset.
  programs.fish = {
    plugins = [
      {
        name = "ai";
        src = pkgs.fishPlugins.ai.src;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        name = "forgit";
        src = pkgs.fishPlugins.forgit.src;
      }
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
    ];
  };

  # fish-ai (the "ai" plugin) reads the OpenAI API key from the
  # OPENAI_API_KEY variable. The key is decrypted at runtime by sops-nix
  # and never written to the Nix store. Fish always loads conf.d/*.fish
  # before config.fish, so this export needs to live in conf.d — ordered
  # before "plugin-ai.fish" — so it already exists when the plugin's own
  # conf.d checks the variable.
  xdg.configFile."fish/conf.d/00-openai-api-key.fish".text = ''
    if test -f ${config.sops.secrets."openai-api-key".path}
      set -gx OPENAI_API_KEY (cat ${config.sops.secrets."openai-api-key".path})
    end
  '';
}
