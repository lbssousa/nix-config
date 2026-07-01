{
  lib,
  tree-sitter,
  fetchFromGitHub,
}:

tree-sitter.buildGrammar {
  language = "gregorio";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "tree-sitter-gregorio";
    rev = "v0.5.2";
    hash = "sha256-olYGpGIKSUp5IV+8jaNwuRDMB6pL6ITeCywfqBuVAp0=";
  };

  meta = with lib; {
    description = "Tree-sitter grammar for Gregorio GABC/NABC Gregorian chant notation (Neovim)";
    homepage = "https://github.com/AISCGre-BR/tree-sitter-gregorio";
    license = licenses.mit;
  };
}
