{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "f97017500df5802ec53d3562893d4beb477c1726";
    hash = "sha256-aGqQSYwQ0ExmM/SF8NTO4icd+X/gEgyM7aoous7yJfY=";
  };

  cargoHash = "sha256-hChIcRMUCIaMuOipdAYOaTF9Vzl1LghslvBrTLgDNk0=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
