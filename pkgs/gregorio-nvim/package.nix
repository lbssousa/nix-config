{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

vimUtils.buildVimPlugin {
  pname = "gregorio-nvim";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "AISCGre-BR";
    repo = "gregorio.nvim";
    rev = "v0.4.0";
    hash = "sha256-SZPDCYd4PSvgM8bMFxD0gCdRVmQ49hDji3ky/wJv+8M=";
  };

  meta = with lib; {
    description = "Neovim plugin for Gregorio GABC/NABC language support";
    homepage = "https://github.com/AISCGre-BR/gregorio.nvim";
    license = licenses.mit;
  };
}
