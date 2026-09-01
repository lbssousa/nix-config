# Imports the OpenPGP public key stored on a connected YubiKey, and trusts
# it — mirroring the omarchy-setup playbook of the same purpose
# (playbooks/yubikey-gpg.yml in lbssousa/omarchy-setup).
#
# git signing itself is NOT configured here: it's already declarative, in
# programs.git.signing.key (home/users/<user>/home.nix).
{ writeShellApplication, gnupg }:

writeShellApplication {
  name = "yubikey-gpg-import";

  runtimeInputs = [ gnupg ];

  text = ''
    card_status=$(gpg --card-status 2>&1) || {
      echo "No OpenPGP card found. Connect the YubiKey and try again." >&2
      echo "$card_status" >&2
      exit 1
    }

    # Imports the public key stored on the card's OpenPGP applet, via the
    # URL it points to — no hardcoded keyserver or fingerprint.
    fetch_output=$(printf 'fetch\nquit\n' | gpg --batch --command-fd 0 --status-fd 1 --card-edit)
    if grep -q 'IMPORT_OK [1-9]' <<<"$fetch_output"; then
      echo "Imported the public key from the card."
    else
      echo "No new key material imported (already up to date, or the card has no key)."
    fi

    signing_key=$(sed -n 's/^Signature key[[:space:]]*\.*:[[:space:]]*\(.*\)$/\1/p' <<<"$card_status" | tr -d ' ')
    if [ -z "$signing_key" ]; then
      echo "Could not read the signing key fingerprint from 'gpg --card-status'." >&2
      exit 1
    fi
    echo "Card signing key: $signing_key"

    # Assigns ultimate trust to the card's key, if not already set — needed
    # for gpg/git to consider it valid for signing without a warning.
    if gpg -k --with-colons "$signing_key" 2>/dev/null | grep -q '^pub:u:'; then
      echo "Key already has ultimate trust."
    else
      echo "$signing_key:6:" | gpg --import-ownertrust
      echo "Assigned ultimate trust to $signing_key."
    fi

    echo
    echo "Done. Cross-check this fingerprint against programs.git.signing.key"
    echo "in home/users/<user>/home.nix — git signing itself is already"
    echo "configured declaratively there, not by this script."
  '';
}
