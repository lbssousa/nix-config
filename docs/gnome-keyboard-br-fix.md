# Correção do teclado ABNT2 no GNOME (Wayland)

## Problema

Em sessões GNOME/Wayland com teclado ABNT2, dois comportamentos errados ocorriam:

1. **Dead key + espaço não produzia o símbolo literal do acento** (ex.: `´`, `~`, `^`) — apenas a combinação AltGr+acento funcionava.
2. **Após relogin, o layout voltava para americano (US)**, mesmo com o layout brasileiro configurado.

## Causa raiz

O IBus é iniciado automaticamente pelo GNOME via `org.freedesktop.IBus.session.GNOME.service`. Ele sobrescreve `GTK_IM_MODULE=ibus` no ambiente da sessão e, se o layout XKB de sistema não estiver configurado, reporta `xkb:us::eng` como engine ativa.

Sem o IBus como intermediário, o GTK4 usa o IM Wayland nativo (Mutter + libxkbcommon), que processa dead keys diretamente via tabelas XKB — sem necessidade de variáveis de ambiente, arquivos Compose ou serviços extras.

## Solução

A correção usa duas camadas, ambas no escopo do sistema.

### 1. Layout XKB de sistema — `modules/system/core/localization.nix`

```nix
services.xserver.xkb = {
  layout  = "br";
  variant = "abnt2";
  model   = "abnt2";
};
```

Necessário para que `localectl` reporte `X11 Layout: br` e, caso o IBus seja iniciado por qualquer motivo, carregue a engine correta (`xkb:br::por`).

> **Observação:** `services.xserver.enable = false` continua válido — esse bloco configura apenas metadados XKB, sem iniciar o servidor Xorg.

### 2. Defaults GNOME de fontes de entrada — `modules/system/desktop/desktop.nix`

```nix
programs.dconf.profiles.user.databases = [{
  settings = {
    "org/gnome/desktop/input-sources" = {
      sources     = [(lib.gvariant.mkTuple ["xkb" "br"])];
      mru-sources = [(lib.gvariant.mkTuple ["xkb" "br"])];
      xkb-model   = "abnt2";
    };
  };
}];
```

- `sources` e `mru-sources`: garantem que o GNOME use o layout `br`. Sem `mru-sources`, o campo fica vazio e o GNOME pode não lembrar o layout entre sessões.
- `xkb-model`: sem ele, o GNOME usa o genérico `pc105+inet` em vez de `abnt2`.

### 3. Drop-in que impede o IBus de iniciar — `home/users/abutre/home.nix`

O IBus é iniciado pelo GNOME via `WantedBy=gnome-session.target`. Um drop-in com `ConditionPathExists` falsa impede sua ativação:

```nix
xdg.configFile."systemd/user/org.freedesktop.IBus.session.GNOME.service.d/disable.conf".text = ''
  [Unit]
  ConditionPathExists=!/run/current-system
'';
```

`/run/current-system` sempre existe em NixOS, portanto a condição é sempre falsa e o serviço nunca inicia. O drop-in fica em `~/.config/systemd/user/`, gerenciado pelo Home Manager.

## Comportamento de dead key + espaço

Com o IM Wayland nativo (Mutter/libxkbcommon), `dead_key + espaço` segue a tabela padrão XKB/pt_BR:

| Sequência | Resultado |
|---|---|
| `dead_acute` + letra | letra com acento agudo (`á`, `é`, ...) |
| `dead_acute` + `dead_acute` | símbolo literal `´` |
| `dead_acute` + `espaço` | apóstrofo `'` (padrão POSIX) |
| `dead_tilde` + `espaço` | til `~` |

Esse é o comportamento canônico da tabela `pt_BR.UTF-8` do libx11.

## Fluxo do Home Manager

O Home Manager neste repositório é **standalone** — o `nixos-rebuild switch` **não** atualiza o perfil do usuário. Após qualquer mudança em `home/users/abutre/home.nix`, é necessário rodar separadamente:

```bash
home-manager switch --flake /etc/nixosabutre@barbudus-gnome
```

O drop-in entra em vigor no próximo login (o IBus já está rodando na sessão corrente).

## O que foi descartado

| Item | Razão |
|---|---|
| `GTK_IM_MODULE=xim` + `environment.d` + serviço `input-method-env-override` | Removidos junto com o IBus — sem IBus, não há o que rever |
| `~/.XCompose` com mapeamentos manuais | Desnecessário sem o GTK built-in IM |
| `include` da tabela `pt_BR.UTF-8` do libx11 via `GTK_IM_MODULE=xim` | O módulo `im-xim.so` não existe no nixpkgs — o GTK built-in IM substituído não processa o `include` corretamente |
| `use-system-keyboard-layout = true` via dconf | Padrão do IBus; irrelevante sem IBus |
| `console.keyMap = "br-abnt2"` para GNOME | Afeta apenas o console TTY |

