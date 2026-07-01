{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.9.4";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "ae14397c9996b54c3e9f8b3d6a6e9a95d836f032";
    hash = "sha256-g40LDutXN3dHqhhCM9c0xplrtOfYHHTw22rDCb6VUsw=";
  };

  cargoHash = "sha256-Ah/XLvdbDMht3LAPfE2mOuI/EJ6IwjZ1z50l53yiBmc=";

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
