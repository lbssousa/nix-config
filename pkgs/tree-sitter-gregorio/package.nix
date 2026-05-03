{ lib, rustPlatform, fetchFromGitHub }:

let
  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "tree-sitter-gregorio";
    rev = "002d6b31d8860324a3a51544b245903e34cbdf80";
    hash = "sha256-Axg0r3pl7WERLSaUL/XRRvXyzJoTPC3lpNAy2T5m0LY=";
  };
in

rustPlatform.buildRustPackage {
  pname = "tree-sitter-gregorio";
  version = "1.0.0-alpha.1";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  doCheck = false;

  meta = with lib; {
    description = "Tree-sitter grammar for Gregorio GABC/NABC Gregorian chant notation";
    homepage = "https://github.com/AISCGre-BR/tree-sitter-gregorio";
    license = licenses.mit;
  };
}
