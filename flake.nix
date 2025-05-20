{
  description = "Gleam Erlang dev environment";

  inputs = {nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";};

  outputs = {
    self,
    nixpkgs,
  }: let
    allSystems = ["x86_64-linux" "aarch64-darwin"];
    # Found from
    # https://nix4noobs.com/flakes/devshells/
    forAllSystems = fn:
      nixpkgs.lib.genAttrs allSystems
      (system: fn {pkgs = import nixpkgs {inherit system;};});
  in {
    devShells = forAllSystems ({pkgs}: {
      default = pkgs.mkShell {
        # name = "nix";
        nativeBuildInputs = with pkgs; [
          gleam
          erlang
          rebar3
        ];
      };
    });
  };
}
