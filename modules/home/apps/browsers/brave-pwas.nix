# PWAs for WhatsApp Web, YouTube, YouTube Music and Microsoft Teams via Brave
{ pkgs, ... }:

let
  brave = "flatpak run com.brave.Browser";

  whatsappIcon = pkgs.fetchurl {
    name = "whatsapp-web.png";
    url = "https://web.whatsapp.com/whatsapp_pwa_icon_512.png";
    hash = "sha256-Sk6DZGzZgLKDbK6YydeXVyM4izVFH1wIEuuhqM4ztw4=";
  };

  youtubeIcon = pkgs.fetchurl {
    name = "youtube.png";
    url = "https://www.youtube.com/img/favicon_144.png";
    hash = "sha256-ru8K/GqhlhJ/nEGt8f0zsXw5Hj/1Vah7HUtMhbPdraU=";
  };

  youtubeMusicIcon = pkgs.fetchurl {
    name = "youtube-music.png";
    url = "https://music.youtube.com/img/favicon_144.png";
    hash = "sha256-EeHjawpnPC0RgpdCUJRpeVk8inVqRIUdD0UpcowaRwk=";
  };

  teamsIcon = pkgs.fetchurl {
    name = "microsoft-teams.png";
    url = "https://teams.microsoft.com/favicon/prod/favicon-512x512.png";
    hash = "sha256-yUD/fwH5oegOXhJ+nnclZHJiOVXI+dCdmrAj6USovbI=";
  };
in
{
  xdg.desktopEntries = {
    whatsapp-web = {
      name = "WhatsApp Web";
      comment = "WhatsApp messages in the browser";
      exec = "${brave} --app=https://web.whatsapp.com";
      icon = "${whatsappIcon}";
      terminal = false;
      categories = [
        "Network"
        "InstantMessaging"
      ];
      startupNotify = true;
    };

    youtube = {
      name = "YouTube";
      comment = "YouTube in the browser";
      exec = "${brave} --app=https://www.youtube.com";
      icon = "${youtubeIcon}";
      terminal = false;
      categories = [
        "Network"
        "AudioVideo"
        "Video"
      ];
      startupNotify = true;
    };

    youtube-music = {
      name = "YouTube Music";
      comment = "YouTube Music in the browser";
      exec = "${brave} --app=https://music.youtube.com";
      icon = "${youtubeMusicIcon}";
      terminal = false;
      categories = [
        "Network"
        "AudioVideo"
        "Music"
      ];
      startupNotify = true;
    };

    microsoft-teams = {
      name = "Microsoft Teams";
      comment = "Microsoft Teams in the browser";
      exec = "${brave} --app=https://teams.microsoft.com";
      icon = "${teamsIcon}";
      terminal = false;
      categories = [
        "Network"
        "InstantMessaging"
      ];
      startupNotify = true;
    };
  };
}
