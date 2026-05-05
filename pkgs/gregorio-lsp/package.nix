{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "99d2c69ba6ec5b0aa8e7f984bc7d03bd43c82f43";
    hash = "sha256-O5c+TdjBq1YSFYbrUJC8GgVTTaIHu60tN4oI8vj2jRE=";
  };

  cargoHash = "sha256-kwW0NJKuq71uogobFNknyNuf60q3Gbg/Ff4lfdzhgR8=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
