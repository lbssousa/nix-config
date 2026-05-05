{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "zed-gregorio";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "zed-gregorio";
    rev = "94face6bd3e7c98aa8b4adeb2fd1e0f9b900772a";
    hash = "sha256-MPSx7T4Pg4Qxrxuxg0UQ0ZtZ3Rs6sj0na+ZQZEw79kY=";
    # Submodules (grammars/gregorio, grammars/tree-sitter-gregorio) are not
    # needed: grammars/gregorio.wasm is pre-compiled and committed to the repo.
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/grammars"
    cp extension.toml extension.wasm "$out/"
    # Add the [lib] section absent from the source manifest.
    # The extension.wasm was compiled with zed_extension_api 0.1.0.
    printf '\n[lib]\nversion = "0.1.0"\n' >> "$out/extension.toml"
    cp grammars/gregorio.wasm "$out/grammars/"
    cp -r languages "$out/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Zed extension for Gregorio GABC/NABC Gregorian chant notation";
    homepage = "https://github.com/AISCGre-BR/zed-gregorio";
    license = licenses.mit;
  };
}
