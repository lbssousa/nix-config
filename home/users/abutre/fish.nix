# Plugins do Fish exclusivos do usuário abutre, incluindo o fish-ai ("ai"),
# que usa a variável OPENAI_API_KEY. Os demais usuários usam o Fish sem
# plugins (ver home/common.nix).
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

  programs.fish = {
    plugins = [
      {
        name = "ai";
        src = pkgs.fishPlugins.ai.src;
      }
      {
        name = "async-prompt";
        src = pkgs.fishPlugins.async-prompt.src;
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

    # fish-ai (plugin "ai") lê a chave da API da OpenAI da variável
    # OPENAI_API_KEY. A chave é decifrada em tempo de execução pelo
    # sops-nix e nunca gravada no Nix store.
    interactiveShellInit = ''
      if test -f ${config.sops.secrets."openai-api-key".path}
        set -gx OPENAI_API_KEY (cat ${config.sops.secrets."openai-api-key".path})
      end
    '';
  };
}
