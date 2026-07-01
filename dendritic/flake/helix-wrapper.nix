# Pacote Helix com configuração integrada via nix-wrapper-modules.
# Exporta packages.helix: binário com XDG_CONFIG_HOME apuntando para config
# gerada na store, incluindo suporte a Gregorio/GABC, bufferline e keybinds.
{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Runtime do Helix estendido com o parser e queries do GABC.
      # Usa pkgs.tree-sitter-gregorio (overlay local) para o parser e queries;
      # o grammar é exposto como gabc.so porque languages.toml declara grammar = "gabc".
      # O Helix resolve: $HELIX_RUNTIME/grammars/<nome>.so
      #                  $HELIX_RUNTIME/queries/<nome>/*.scm
      runtimeComGabc = pkgs.runCommand "helix-runtime-com-gabc" { } ''
        # grammars: todos os originais + gabc.so
        mkdir -p "$out/grammars"
        for so in ${pkgs.helix.passthru.runtime}/grammars/*.so; do
          ln -s "$so" "$out/grammars/$(basename "$so")"
        done
        ln -s "${pkgs.tree-sitter-gregorio}/parser" "$out/grammars/gregorio.so"

        # queries: todos os diretórios originais + diretório gabc/
        mkdir -p "$out/queries"
        for qdir in ${pkgs.helix.passthru.runtime}/queries/*/; do
          ln -s "$qdir" "$out/queries/$(basename "$qdir")"
        done
        # O Helix resolve queries pelo nome da linguagem (não do grammar):
        # queries/gabc/ é necessário para que o realce de sintaxe funcione.
        mkdir -p "$out/queries/gabc"
        for scm in "${pkgs.tree-sitter-gregorio.src}/queries/"*.scm; do
          ln -s "$scm" "$out/queries/gabc/$(basename "$scm")"
        done
      '';

      # TeXLive pequeno ampliado com latexmk — pdflatex + latexmk no PATH
      # sem impor uma instalação de sistema. A adição via --suffix garante que
      # uma instalação de sistema (se existir) tenha precedência.
      texliveComLatexmk = pkgs.texliveMinimal.withPackages (p: [ p.latexmk ]);

      # Reempacota o Helix com HELIX_RUNTIME estendido e LSPs no PATH.
      # Envolve .hx-wrapped diretamente para sobrescrever o HELIX_RUNTIME
      # já definido pelo wrapper original do nixpkgs.
      helixComGabc =
        pkgs.runCommand "helix-com-gabc"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            inherit (pkgs.helix) version;
            # meta.mainProgram informa ao nix-wrapper-modules que o binário
            # principal é "hx", garantindo que binName e exePath sejam
            # detectados corretamente para criar o wrapper com XDG_CONFIG_HOME.
            meta.mainProgram = "hx";
          }
          ''
            mkdir -p "$out/bin"

            makeBinaryWrapper "${pkgs.helix}/bin/.hx-wrapped" "$out/bin/hx" \
              --inherit-argv0 \
              --set HELIX_RUNTIME "${runtimeComGabc}" \
              --suffix PATH : "${
                lib.makeBinPath [
                  pkgs.texlab
                  pkgs.ltex-ls
                  pkgs.zathura
                  texliveComLatexmk
                  pkgs.gregorio-lsp
                ]
              }"

            ln -s "${pkgs.helix}/bin/.hx-wrapped" "$out/bin/.hx-wrapped"
            ln -s "${pkgs.helix}/share" "$out/share"
          '';
    in
    {
      packages.helix = inputs.wrapper-modules.wrappers.helix.wrap {
        inherit pkgs;
        package = helixComGabc;

        settings = {
          theme = "catppuccin_mocha";

          editor = {
            # ── Visualização ────────────────────────────────────────────────────
            # Barra de buffers aberta: visível quando 2+ arquivos abertos
            bufferline = "multiple";
            "line-number" = "relative";
            cursorline = true;
            # Indicador de modo colorido na statusline (normal/insert/select)
            "color-modes" = true;
            "true-color" = true;
            "popup-border" = "all";

            "indent-guides" = {
              render = true;
              character = "╎";
            };

            "cursor-shape" = {
              insert = "bar";
              normal = "block";
              select = "underline";
            };

            # ── LSP ─────────────────────────────────────────────────────────────
            lsp = {
              "display-messages" = true;
              "display-inlay-hints" = true;
              "auto-signature-help" = true;
              "display-signature-help-docs" = true;
            };

            # ── Diagnósticos inline ─────────────────────────────────────────────
            "end-of-line-diagnostics" = "hint";
            "inline-diagnostics" = {
              "cursor-line" = "warning";
            };

            # ── Salvamento automático ───────────────────────────────────────────
            "auto-save" = {
              "focus-lost" = true;
            };

            # ── File picker ─────────────────────────────────────────────────────
            "file-picker" = {
              # Mostrar arquivos ocultos no picker (útil para .env, .gitignore, etc.)
              hidden = false;
            };

            # ── Indentação ──────────────────────────────────────────────────────
            "indent-heuristic" = "hybrid";

            # ── Statusline ──────────────────────────────────────────────────────
            statusline = {
              left = [
                "mode"
                "spinner"
                "file-name"
                "file-modification-indicator"
                "read-only-indicator"
              ];
              center = [ ];
              right = [
                "diagnostics"
                "selections"
                "position"
                "file-encoding"
                "file-type"
              ];
              mode = {
                normal = "NORMAL";
                insert = "INSERT";
                select = "SELECT";
              };
            };
          };

          # ── Atalhos de teclado ──────────────────────────────────────────────
          keys = {
            normal = {
              # Salvar com Ctrl+S (normal e com todos os buffers)
              "C-s" = ":w";
              "C-S-s" = ":wa";

              # Sair do modo visual sem cursor duplo
              esc = [
                "collapse_selection"
                "keep_primary_selection"
              ];

              # Navegação estrutural via tree-sitter (nós do AST)
              "C-h" = "select_prev_sibling";
              "C-j" = "shrink_selection";
              "C-k" = "expand_selection";
              "C-l" = "select_next_sibling";

              # Mover linhas inteiras (Alt+j/k)
              "A-j" = [
                "extend_to_line_bounds"
                "delete_selection"
                "paste_after"
              ];
              "A-k" = [
                "extend_to_line_bounds"
                "delete_selection"
                "move_line_up"
                "paste_before"
              ];

              # Abrir linha sem entrar em insert (o = open_below + normal_mode)
              o = [
                "open_below"
                "normal_mode"
              ];
              O = [
                "open_above"
                "normal_mode"
              ];
            };

            insert = {
              # Salvar sem sair do modo de inserção
              "C-s" = ":w";
            };

            select = {
              # Mesma limpeza de seleção no modo visual
              esc = [
                "collapse_selection"
                "keep_primary_selection"
                "normal_mode"
              ];
            };
          };
        };

        # ── Linguagens: LaTeX + GABC/Gregorio ────────────────────────────────
        languages = {
          "language-server" = {
            texlab = {
              command = "texlab";
              config.texlab = {
                build = {
                  executable = "latexmk";
                  args = [
                    "-pdf"
                    "-interaction=nonstopmode"
                    "-synctex=1"
                    "%f"
                  ];
                  onSave = true;
                };
                "forwardSearch" = {
                  executable = "zathura";
                  args = [
                    "--synctex-forward"
                    "%l:1:%f"
                    "%p"
                  ];
                };
                chktex = {
                  "onOpenAndSave" = true;
                };
              };
            };

            # LTeX: verificação gramatical e ortográfica via LanguageTool.
            # Complementa o texlab (sintaxe/build) com diagnósticos de escrita.
            # Idioma padrão pt-BR; o usuário pode sobrescrever por arquivo via
            # magic comment  `% ltex: language=en-US` no topo do .tex.
            ltex = {
              command = "ltex-ls";
              config.ltex = {
                language = "pt-BR";
                additionalRules = {
                  motherTongue = "pt-BR";
                };
              };
            };
            # gregorio-lsp: LSP para notação de canto gregoriano GABC/NABC.
            # Empacotado no overlay local (pkgs.gregorio-lsp).
            gregorio-lsp = {
              command = "gregorio-lsp";
            };
          };

          language = [
            {
              name = "latex";
              "language-servers" = [
                "texlab"
                "ltex"
              ];
            }
            # GABC: notação de canto gregoriano (AISCGre-BR/tree-sitter-gregorio)
            {
              name = "gabc";
              scope = "source.gabc";
              "file-types" = [ "gabc" ];
              "comment-token" = "%";
              grammar = "gregorio";
              "language-servers" = [ "gregorio-lsp" ];
              # grefmt lê stdin → escreve stdout quando nenhum arquivo é passado
              formatter = {
                command = "grefmt";
              };
              indent = {
                "tab-width" = 2;
                unit = "  ";
              };
              "auto-pairs" = {
                "(" = ")";
                "[" = "]";
                "{" = "}";
                "<" = ">";
              };
            }
          ];
        };
      };
    };
}
