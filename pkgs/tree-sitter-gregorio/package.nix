{ lib, rustPlatform, fetchFromGitHub }:

let
  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "tree-sitter-gregorio";
    rev = "de3ea23724220584d0deda4435c1751b092ae804";
    hash = "sha256-Qm8Mjmi2n+aistdDcuRr4jpJKgOHgAN8GcpIy+xHRlE=";
  };
in

rustPlatform.buildRustPackage {
  pname = "tree-sitter-gregorio";
  version = "0.0.1";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = with lib; {
    description = "Tree-sitter grammar for Gregorio GABC/NABC Gregorian chant notation";
    homepage = "https://github.com/AISCGre-BR/tree-sitter-gregorio";
    license = licenses.mit;
  };
}
