# Gerado manualmente; atualizar hashes ao trocar de versão.
rec {
  pname = "brave-origin-beta";
  version = "1.92.110";
  channel = "beta";

  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin-beta_${version}_amd64.deb";
      hash = "sha256-b0xMzAqfTfY08BvQbGoG4JA/sjXwyEZRW3mDUYCa9M8=";
    };
  };
}
