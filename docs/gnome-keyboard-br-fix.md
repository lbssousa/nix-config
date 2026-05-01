# Correção do teclado ABNT2 no GNOME (Wayland)

## Problema

Em sessões GNOME/Wayland com teclado ABNT2, dois comportamentos errados ocorriam:

1. **Dead key + espaço não produzia o símbolo literal do acento** (ex.: `´`, `~`, `^`) — apenas a combinação AltGr+acento funcionava.
2. **Após relogin, o layout voltava para americano (US)**, mesmo com o layout brasileiro configurado.

## Causa raiz

O GNOME inicia o IBus automaticamente via `org.freedesktop.IBus.session.GNOME.service`. O IBus intercepta os eventos de teclado e os processa com sua própria implementação de tabelas Compose (`IBusEngineSimple`), que é **completamente independente** do libxkbcommon. Isso cria um conflito:

- O layout XKB `br` define `dead_acute + space → ´` (U+00B4, SPACING ACUTE ACCENT) via máquina de estados XKB.
- As tabelas Compose do IBus (pt_BR.UTF-8 do libx11) definem `<dead_acute> <space> → '` (apóstrofo U+0027, convenção X11 canônica).

O IBus responde `TRUE` (consumiu o evento) antes que o Mutter/libxkbcommon processe a combinação, portanto a tabela Compose do IBus vence sempre. O arquivo `~/.XCompose` padrão não resolve porque o IBus carrega `~/.config/ibus/Compose` com exclusividade — apenas se nenhum arquivo custom existir ele prossegue para os arquivos de locale.

## Solução

A correção usa três camadas.

### 1. Layout XKB de sistema — `modules/system/core/localization.nix`

```nix
services.xserver.xkb = {
  layout  = "br";
  variant = "abnt2";
  model   = "abnt2";
};
```

Necessário para que `localectl` reporte `X11 Layout: br` e o IBus carregue a engine correta (`xkb:br::por`).

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

### 3. Arquivo Compose do IBus e ajustes dconf — `home/users/abutre/home.nix`

O IBus carrega `~/.config/ibus/Compose` como **primeira e exclusiva** fonte de tabela Compose quando o arquivo existe. A estratégia é incluir a tabela completa do locale e sobrescrever apenas os mapeamentos problemáticos:

```nix
xdg.configFile."ibus/Compose".text = ''
  include "%L"

  <dead_acute>      <space> : "´" U00B4
  <dead_grave>      <space> : "`" grave
  <dead_tilde>      <space> : "~" asciitilde
  <dead_circumflex> <space> : "^" asciicircum
  <dead_diaeresis>  <space> : "¨" U00A8
'';
```

- `include "%L"` expande para a tabela do locale do sistema (`pt_BR.UTF-8/Compose`), carregando todas as combinações de letras acentuadas.
- As entradas subsequentes têm precedência sobre as entradas do `include`, sobrescrevendo apenas `dead_key + space`.

Também é necessário configurar o IBus para operar corretamente em Wayland puro:

```nix
dconf.settings."desktop/ibus/general" = {
  use-system-keyboard-layout = true;   # evita chamada a setxkbmap (ausente em Wayland)
  preload-engines = [ "xkb:br::por" ]; # engine correta na inicialização da sessão
};
```

## Comportamento de dead key + espaço

Com o IBus e o arquivo Compose configurado:

| Sequência | Resultado |
|---|---|
| `dead_acute` + letra | letra com acento agudo (`á`, `é`, ...) |
| `dead_acute` + `dead_acute` | símbolo literal `´` (via tabela pt_BR) |
| `dead_acute` + `espaço` | `´` U+00B4 (SPACING ACUTE ACCENT) |
| `dead_grave` + `espaço` | `` ` `` |
| `dead_tilde` + `espaço` | `~` |
| `dead_circumflex` + `espaço` | `^` |
| `dead_diaeresis` + `espaço` | `¨` |

## Fluxo do Home Manager

O Home Manager neste repositório é **standalone** — o `nixos-rebuild switch` **não** atualiza o perfil do usuário. Após qualquer mudança em `home/users/abutre/home.nix`, é necessário rodar separadamente:

```bash
home-manager switch --flake /etc/nixosabutre@barbudus-gnome
```

O arquivo `~/.config/ibus/Compose` entra em vigor no próximo restart do serviço IBus (ou relogin).

## O que foi descartado

| Item | Razão |
|---|---|
| Drop-in `ConditionPathExists=!/run/current-system` desabilitando IBus | Solução anterior mais agressiva; substituída pelo override do Compose |
| `GTK_IM_MODULE=xim` + serviço `input-method-env-override` | `im-xim.so` não existe no nixpkgs para Wayland |
| `~/.XCompose` com mapeamentos manuais | O IBus não lê `~/.XCompose` quando `~/.config/ibus/Compose` existe |
| `include` da tabela pt_BR via `GTK_IM_MODULE=xim` | O módulo `im-xim.so` ausente impede esse caminho |
| `console.keyMap = "br-abnt2"` para GNOME | Afeta apenas o console TTY |

