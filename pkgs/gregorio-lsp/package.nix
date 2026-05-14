{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "b7221ba8d17e1fc4719b41e7efb33de54a3cee55";
    hash = "sha256-N+kh7DdxpA/qvIU9JOlZalfPWF1oWrA7TbnoGalslQA=";
  };

  cargoHash = "sha256-2iifKbDTLcbLRLW1CV6pGX+V7I5gixdtdX1XnhpbsEM=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
