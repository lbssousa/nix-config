# Generated manually; update hashes when bumping the version.
rec {
  pname = "brave-origin-nightly";
  version = "1.93.10";
  channel = "nightly";

  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin-nightly_${version}_amd64.deb";
      hash = "sha256-92S8uUR/K7TS0oqn2qYYdvhP2wkd5Md4NsWRtDzQ3kc=";
    };
  };
}
