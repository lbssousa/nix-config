{ lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "zed-gregorio";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "zed-gregorio";
    rev = "1ff3746c9706a3a22b569ea163e0f5f6fcfd900e";
    hash = "sha256-csEYsSEuhJD67e5IxOywVFMk9joDOIY+JlGnbJ77U/s=";
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
