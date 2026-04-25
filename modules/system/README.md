# modules/system

Módulos NixOS system-wide — utilizados pelo `nixos-rebuild switch`.

Cada subpasta agrupa módulos por categoria funcional.

## Categorias

| Pasta | Descrição |
|-------|-----------|
| [audio/](audio/) | Servidor de áudio PipeWire com compatibilidade PulseAudio/JACK |
| [boot/](boot/) | Gerenciador de boot (systemd-boot/lanzaboote) e Plymouth |
| [containers/](containers/) | Podman rootless e Distrobox |
| [core/](core/) | Configurações base do sistema e impermanência |
| [desktop/](desktop/) | Ambiente GNOME + Flatpak (experiência tipo Silverblue/Bluefin) |
| [hardware/](hardware/) | Impressão (CUPS + drivers Epson) e hardware específico |
| [network/](network/) | Servidor SSH e redes Wi-Fi declarativas (NetworkManager) |
| [security/](security/) | TPM2 para desbloqueio automático do LUKS |
| [shell/](shell/) | Shells disponíveis no sistema (Bash, Fish, Zsh) |
| [tools/](tools/) | Pacotes essenciais do sistema |
| [users/](users/) | Definição de usuários, grupos e política de sudo |

## Uso

Importe os módulos desejados no arquivo de configuração do host:

```nix
# hosts/<host>/configuration.nix
imports = [
  ../../modules/system/core/common.nix
  ../../modules/system/core/impermanence.nix
  ../../modules/system/audio/audio.nix
  ../../modules/system/boot/boot.nix
  ../../modules/system/containers/containers.nix
  ../../modules/system/desktop/desktop.nix
  ../../modules/system/hardware/printing.nix
  ../../modules/system/network/ssh.nix
  ../../modules/system/network/wifi.nix
  ../../modules/system/security/tpm2.nix
  ../../modules/system/shell/shells.nix
  ../../modules/system/tools/packages.nix
  ../../modules/system/users/users.nix
];
```
