{
  lib,
  tree-sitter,
  fetchFromGitHub,
}:

let
  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "tree-sitter-gregorio";
    rev = "v0.5.2";
    hash = "sha256-olYGpGIKSUp5IV+8jaNwuRDMB6pL6ITeCywfqBuVAp0=";
  };
in
tree-sitter.buildGrammar {
  language = "gregorio";
  version = "0.5.2";
  inherit src;
  passthru = { inherit src; };

  meta = with lib; {
    description = "Tree-sitter grammar for Gregorio GABC/NABC Gregorian chant notation";
    homepage = "https://github.com/AISCGre-BR/tree-sitter-gregorio";
    license = licenses.mit;
  };
}
