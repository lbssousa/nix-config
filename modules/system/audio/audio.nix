# Audio module: PipeWire with PulseAudio/JACK compatibility
{ lib, ... }:

{
  # Disable PulseAudio (replaced by PipeWire)
  services.pulseaudio.enable = false;

  # RTKit for real-time priority
  security.rtkit.enable = true;

  # PipeWire as the audio server
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = true; # PulseAudio compatibility
    jack.enable = lib.mkDefault true; # JACK compatibility
    wireplumber.enable = true;
  };
}
