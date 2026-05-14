{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "4078e21c14911fdcda699af823c7008ec5da8a27";
    hash = "sha256-Y+2pblV2ceAScK21jXHoDgFfGdNmluATF36RQtVo6Z0=";
  };

  cargoHash = "sha256-jozJEpJAtLxPoF6l7FVbWwEUnE7Va5DQboGlpchCe2k=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
