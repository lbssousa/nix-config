{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "tree-sitter-gregorio";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "tree-sitter-gregorio";
    rev = "c9034de8f8c1c1605e9ccde29500f08e72ea51ff";
    hash = "sha256-olYGpGIKSUp5IV+8jaNwuRDMB6pL6ITeCywfqBuVAp0=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";
  doCheck = false;

  meta = with lib; {
    description = "Tree-sitter grammar for Gregorio GABC/NABC Gregorian chant notation";
    homepage = "https://github.com/AISCGre-BR/tree-sitter-gregorio";
    license = licenses.mit;
  };
}
