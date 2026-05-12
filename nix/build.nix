{ pkgs ? import <nixpkgs> }:

pkgs.flutter.buildFlutterApplication rec {

  pname = "wisp";
  version = "0.0.1";

  src = ./..;

  # autoPubspecLock = src + "/pubspec.lock";
  pubspecLock = pkgs.lib.importJSON (src + "/pubspec.lock.json");
  gitHashes = pkgs.lib.importJSON (src + "/pubspecGitHashes.json");

  # nativeBuildInputs = with pkgs; [ ];

}
