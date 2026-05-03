{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "zed-gregorio";
  version = "1.0.0-alpha.1";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "zed-gregorio";
    rev = "432735956e23ee8584dbb951c3d48d3578ed1772";
    hash = "sha256-hgtaaY0oJM5zciL5lC24/rjdZ78d0CRjz0NNKE/x504=";
    # Submódulos (grammars/gregorio, grammars/tree-sitter-gregorio) não são
    # necessários: o grammars/gregorio.wasm já está pré-compilado no repositório.
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/grammars"
    cp extension.toml extension.wasm "$out/"
    cp grammars/gregorio.wasm "$out/grammars/"
    cp -r languages "$out/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Extensão Zed para notação de canto gregoriano GABC/NABC";
    homepage = "https://github.com/AISCGre-BR/zed-gregorio";
    license = licenses.mit;
  };
}
