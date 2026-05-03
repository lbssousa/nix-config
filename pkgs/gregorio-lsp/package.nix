{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "1.0.0-alpha.1";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "f0ff80d1860c6aa4d24e8b146757cd441a2f1930";
    hash = "sha256-6R5wh4ZMYQ58qu1CnwvPZlsUk9OeDQ+9OfASo2+W5yI=";
  };

  cargoHash = "sha256-GDkO8mHRTlPrIkKc61MxWVmCev4l7U1PHhqB2ApOUSs=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
