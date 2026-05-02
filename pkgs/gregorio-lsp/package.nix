{ lib, buildNpmPackage, fetchFromGitHub, gregolint }:

let
  gregolintSrc = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregolint";
    rev = "2001776c532373f05c1b3efc33642cdd3e2ea214";
    hash = "sha256-bNzsGo2Xp4ecziyryQbE9r+60PTwiA3gNd0TQjTxOb0=";
  };
in

buildNpmPackage rec {
  pname = "gregorio-lsp";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio-lsp";
    rev = "b87431cfa2481ec6cbb5afd3196bd5b8f0444b38";
    hash = "sha256-1UQXwTIpw0jVo0hswmVsDG4bV2I3vEE2gAPN+Jcy3kQ=";
  };

  npmDepsHash = "sha256-pG2okWa7aQKqc50KPWhx532nkaECO3WRA5nbXB5Bfps=";

  # Desabilita o script postinstall (apenas imprime info sobre tree-sitter opcional)
  npmInstallFlags = [ "--ignore-scripts" ];

  # Cria ../gregolint (relativo ao diretório do pacote) para que o npm ci
  # consiga resolver a dependência file:../gregolint do package-lock.json.
  # Pré-popula dist/ do gregolint já construído para resolução de tipos TypeScript.
  preConfigure = ''
    mkdir -p "$NIX_BUILD_TOP/gregolint"
    cp -r ${gregolintSrc}/. "$NIX_BUILD_TOP/gregolint/"
    chmod -R u+w "$NIX_BUILD_TOP/gregolint"
    cp -r ${gregolint}/lib/node_modules/gregolint/dist/. "$NIX_BUILD_TOP/gregolint/dist/"
  '';

  # Substitui o symlink dangling de gregolint no $out pela versão construída
  # e remove a dependência opcional tree-sitter-gregorio quando ela virar
  # um symlink quebrado no pacote final. O próprio projeto faz fallback para
  # o parser TypeScript quando tree-sitter não está disponível.
  postInstall = ''
    local gregolintDest="$out/lib/node_modules/gregorio-lsp/node_modules/gregolint"
    local treeSitterGregorioDest="$out/lib/node_modules/gregorio-lsp/node_modules/tree-sitter-gregorio"

    rm -rf "$gregolintDest"
    cp -r ${gregolint}/lib/node_modules/gregolint "$gregolintDest"

    if [ -L "$treeSitterGregorioDest" ] && [ ! -e "$treeSitterGregorioDest" ]; then
      rm -f "$treeSitterGregorioDest"
    fi
  '';

  meta = with lib; {
    description = "Language Server Protocol for Gregorio GABC/NABC notation";
    homepage = "https://github.com/AISCGre-BR/gregorio-lsp";
    license = licenses.mit;
    mainProgram = "gregorio-lsp";
  };
}
