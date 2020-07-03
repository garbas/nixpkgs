{ pkgs ? import <nixpkgs> {}
}:

let
  inherit (pkgs.poetry2nix) mkPoetryApplication;
in mkPoetryApplication {
  projectDir = ./.;
  python = pkgs.python38;
  # overrides = overrides.withDefaults (self: super: {
  # });
  nativeBuildInputs = [
    pkgs.poetry
  ];
  shellHook = ''
  '';
}
