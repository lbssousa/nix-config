# Módulo de áudio: PipeWire com compatibilidade PulseAudio/JACK
{ config, lib, pkgs, ... }:

{
  # Desabilitar PulseAudio (substituído pelo PipeWire)
  services.pulseaudio.enable = false;

  # RTKit para prioridade em tempo real
  security.rtkit.enable = true;

  # PipeWire como servidor de áudio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = true; # Compatibilidade com PulseAudio
    jack.enable = lib.mkDefault true; # Compatibilidade com JACK
    wireplumber.enable = true;
  };
}
