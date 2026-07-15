{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "gregorio-lsp";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "e3a934b375701e2d125dcd035abeca065431a8a5";
    hash = "sha256-tRM3LoucNzig1TICZYigTaV9tK36YuuWMO0DzLWE79s=";
  };

  cargoHash = "sha256-/X9KUBhXSLDhND6gMdNlIAQbPHNFJmjWFPLfGSqXxaM=";

  postPatch = ''
    # Remove gregorio-wasm from workspace to avoid wasm-bindgen dependency
    sed -i '/gregorio-wasm/d' Cargo.toml
  '';

  cargoBuildFlags = [ "-p" "gregorio-server" ];

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
