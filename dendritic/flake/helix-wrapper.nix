# Helix package with config baked in via nix-wrapper-modules.
# Exports packages.helix: a binary with XDG_CONFIG_HOME pointing to config
# generated in the store, including Gregorio/GABC support, bufferline and keybinds.
{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Helix runtime extended with the GABC parser and queries.
      # Uses pkgs.tree-sitter-gregorio (local overlay) for the parser and queries;
      # the grammar is exposed as gabc.so because languages.toml declares grammar = "gabc".
      # Helix resolves: $HELIX_RUNTIME/grammars/<name>.so
      #                 $HELIX_RUNTIME/queries/<name>/*.scm
      runtimeComGabc = pkgs.runCommand "helix-runtime-com-gabc" { } ''
        # grammars: all originals + gabc.so
        mkdir -p "$out/grammars"
        for so in ${pkgs.helix.passthru.runtime}/grammars/*.so; do
          ln -s "$so" "$out/grammars/$(basename "$so")"
        done
        ln -s "${pkgs.tree-sitter-gregorio}/parser" "$out/grammars/gregorio.so"

        # queries: all original directories + gabc/ directory
        mkdir -p "$out/queries"
        for qdir in ${pkgs.helix.passthru.runtime}/queries/*/; do
          ln -s "$qdir" "$out/queries/$(basename "$qdir")"
        done
        # Helix resolves queries by language name (not grammar name):
        # queries/gabc/ is required for syntax highlighting to work.
        mkdir -p "$out/queries/gabc"
        for scm in "${pkgs.tree-sitter-gregorio.src}/queries/"*.scm; do
          ln -s "$scm" "$out/queries/gabc/$(basename "$scm")"
        done
      '';

      # Small TeXLive extended with latexmk — pdflatex + latexmk on PATH
      # without imposing a system install. Adding it via --suffix ensures a
      # system install (if any) takes precedence.
      texliveComLatexmk = pkgs.texliveMinimal.withPackages (p: [ p.latexmk ]);

      # Repackages Helix with an extended HELIX_RUNTIME and LSPs on PATH.
      # Wraps .hx-wrapped directly to override the HELIX_RUNTIME already set
      # by the original nixpkgs wrapper.
      helixComGabc =
        pkgs.runCommand "helix-com-gabc"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            inherit (pkgs.helix) version;
            # meta.mainProgram tells nix-wrapper-modules that the main binary
            # is "hx", ensuring binName and exePath are detected correctly to
            # build the wrapper with XDG_CONFIG_HOME.
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
            # ── Display ───────────────────────────────────────────────────────
            # Open buffer bar: visible when 2+ files are open
            bufferline = "multiple";
            "line-number" = "relative";
            cursorline = true;
            # Colored mode indicator in the statusline (normal/insert/select)
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

            # ── Inline diagnostics ──────────────────────────────────────────────
            "end-of-line-diagnostics" = "hint";
            "inline-diagnostics" = {
              "cursor-line" = "warning";
            };

            # ── Auto-save ───────────────────────────────────────────────────────
            "auto-save" = {
              "focus-lost" = true;
            };

            # ── File picker ─────────────────────────────────────────────────────
            "file-picker" = {
              # Show hidden files in the picker (useful for .env, .gitignore, etc.)
              hidden = false;
            };

            # ── Indentation ─────────────────────────────────────────────────────
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

          # ── Keybindings ───────────────────────────────────────────────────────
          keys = {
            normal = {
              # Save with Ctrl+S (normal and across all buffers)
              "C-s" = ":w";
              "C-S-s" = ":wa";

              # Exit visual mode without a duplicate cursor
              esc = [
                "collapse_selection"
                "keep_primary_selection"
              ];

              # Structural navigation via tree-sitter (AST nodes)
              "C-h" = "select_prev_sibling";
              "C-j" = "shrink_selection";
              "C-k" = "expand_selection";
              "C-l" = "select_next_sibling";

              # Move whole lines (Alt+j/k)
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

              # Open a line without entering insert (o = open_below + normal_mode)
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
              # Save without leaving insert mode
              "C-s" = ":w";
            };

            select = {
              # Same selection cleanup in visual mode
              esc = [
                "collapse_selection"
                "keep_primary_selection"
                "normal_mode"
              ];
            };
          };
        };

        # ── Languages: LaTeX + GABC/Gregorio ──────────────────────────────────
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

            # LTeX: grammar and spell checking via LanguageTool.
            # Complements texlab (syntax/build) with writing diagnostics.
            # Default language is pt-BR; the user can override it per file via
            # the magic comment `% ltex: language=en-US` at the top of the .tex.
            ltex = {
              command = "ltex-ls";
              config.ltex = {
                language = "pt-BR";
                additionalRules = {
                  motherTongue = "pt-BR";
                };
              };
            };
            # gregorio-lsp: LSP for GABC/NABC Gregorian chant notation.
            # Packaged in the local overlay (pkgs.gregorio-lsp).
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
            # GABC: Gregorian chant notation (AISCGre-BR/tree-sitter-gregorio)
            {
              name = "gabc";
              scope = "source.gabc";
              "file-types" = [ "gabc" ];
              "comment-token" = "%";
              grammar = "gregorio";
              "language-servers" = [ "gregorio-lsp" ];
              # grefmt reads stdin → writes stdout when no file is passed
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
