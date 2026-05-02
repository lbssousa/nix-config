{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "gregolint";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregolint";
    rev = "2001776c532373f05c1b3efc33642cdd3e2ea214";
    hash = "sha256-bNzsGo2Xp4ecziyryQbE9r+60PTwiA3gNd0TQjTxOb0=";
  };

  npmDepsHash = "sha256-Zbr1p7zqFPhwg5C317choxOYVEBWE0imjtDMayleNDk=";

  meta = with lib; {
    description = "CLI linter for Gregorio .gabc files";
    homepage = "https://github.com/AISCGre-BR/gregolint";
    license = licenses.mit;
    mainProgram = "gregolint";
  };
}
