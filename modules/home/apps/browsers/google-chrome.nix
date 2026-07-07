# User module: Google Chrome via the native Home Manager module
{ pkgs, ... }:

{
  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };

}
