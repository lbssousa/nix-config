{ ... }:

{
  # Arquivo de ação Polkit necessário para o desbloqueio biométrico do Bitwarden.
  # Sem este arquivo, a opção de biometria não aparece nas configurações do app.
  environment.etc."polkit-1/actions/com.bitwarden.Bitwarden.policy".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC
     "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">

    <policyconfig>
        <action id="com.bitwarden.Bitwarden.unlock">
          <description>Unlock Bitwarden</description>
          <message>Authenticate to unlock Bitwarden</message>
          <defaults>
            <allow_any>no</allow_any>
            <allow_inactive>no</allow_inactive>
            <allow_active>auth_self</allow_active>
          </defaults>
        </action>
    </policyconfig>
  '';
}
