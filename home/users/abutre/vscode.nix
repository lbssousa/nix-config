# Configuração do VSCode para o usuário abutre
{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    profiles.default.extensions =
      (with pkgs.vscode-extensions; [
        davidanson.vscode-markdownlint
        eamodio.gitlens
        github.codespaces
        github.copilot
        github.copilot-chat
        github.vscode-github-actions
        james-yu.latex-workshop
        jnoortheen.nix-ide
        mkhl.direnv
        ms-ceintl.vscode-language-pack-pt-br
        ms-vscode-remote.remote-containers
        pkief.material-icon-theme
        tecosaur.latex-utilities
        yzhang.markdown-all-in-one
      ])
      ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "gabc-gregorian-chant-notation";
          publisher = "gregoriano-br";
          version = "1.1.0";
          sha256 = "sha256-Qcr5ceuV2qCEHTQWMAWqbhW3bJMFriHQlSfaBvpVibc=";
        }
        {
          name = "remotehub";
          publisher = "github";
          version = "0.64.0";
          sha256 = "sha256-Nh4PxYVdgdDb8iwHHUbXwJ5ZbMruFB6juL4Yg/wdKMY=";
        }
        {
          name = "lilypond-syntax";
          publisher = "jeandeaual";
          version = "0.1.1";
          sha256 = "sha256-Lo4Opa9PaMlCxLRx+6n6r2f/El2+N0gEMAO6cd9l7Fo=";
        }
        {
          name = "scheme";
          publisher = "jeandeaual";
          version = "0.2.0";
          sha256 = "sha256-ddehU7YeHv62QjZiTk0HV9wHgz8mVDuyMpH/w89bh6s=";
        }
        {
          name = "lilypond-formatter";
          publisher = "lhl2617";
          version = "0.2.3";
          sha256 = "sha256-4wjZKQvfqQpVlBvnR/s0Okipf7Xwhzol71uW0uOtk3k=";
        }
        {
          name = "lilypond-pdf-preview";
          publisher = "lhl2617";
          version = "0.2.8";
          sha256 = "sha256-otDRrc49Ej1So29quTX/evfotQbH/p+IeIb35votKi0=";
        }
        {
          name = "lilypond-snippets";
          publisher = "lhl2617";
          version = "0.1.1";
          sha256 = "sha256-Y/c5uxbTvOULNzJk8LOhVtTuzRa24sHnauUQhmIzHDU=";
        }
        {
          name = "vslilypond";
          publisher = "lhl2617";
          version = "1.7.3";
          sha256 = "sha256-zWs+kEu1YH5Vp/wPr/WrLmeblqIwKeqiH9difCaiYJs=";
        }
        {
          name = "extension-test-runner";
          publisher = "ms-vscode";
          version = "0.0.14";
          sha256 = "sha256-YkNSngj4oVlSOvG6RC6n9KhsV6Z5fcP14ah9qDejn3s=";
        }
        {
          name = "remote-repositories";
          publisher = "ms-vscode";
          version = "0.42.0";
          sha256 = "sha256-cYbkCcNsoTO6E5befw/ZN3yTW262APTCxyCJ/3z84dc=";
        }
      ];
  };
}
