{ pkgs ? import <nixpkgs> {} }:

(pkgs.buildFHSUserEnv {
  name = "fnf-oasis-dev-env";
  
  targetPkgs = pkgs: (with pkgs; [
    # Narzędzia podstawowe
    nodejs
    git
    unzip
    gcc
    gnumake

    # Biblioteki potrzebne do kompilacji i działania okna/dźwięku (odpowiednik tego co ma steam-run)
    SDL2
    alsa-lib
    libGL
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXi
    openal
  ]);

  # Po uruchomieniu nix-shell, wejdziesz do standardowego basha z ustawionym środowiskiem
  runScript = "bash";
}).env
