{
  description = "Gleam Erlang dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-old.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-old,
  }: let
    allSystems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = fn: (nixpkgs.lib.genAttrs allSystems
      (system:
        fn {
          pkgs = import nixpkgs {inherit system;};
          pkgs-old = import nixpkgs-old {inherit system;};
        }));
  in {
    devShells = forAllSystems ({pkgs, pkgs-old}: {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          gleam
          erlang
          rebar3
          pkgs-old.go-migrate
          elixir_1_18
          beam27Packages.hex
        ];
      };
    });
  };
}
