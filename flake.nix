{
  description = "jshvn dotfiles: one nix-darwin configuration per laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
    }:
    let
      lib = nixpkgs.lib;
      # the <name> of each <name>.nix in a directory; any other file there (a README.md) is not a module
      nixFiles =
        dir:
        map (lib.removeSuffix ".nix") (
          builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir dir))
        );
      # machines/<name>.nix is the whole list: one file per physical laptop, chosen explicitly
      # at switch time (`darwin-rebuild switch --flake .#lerasium`), never inferred from the hostname
      names = nixFiles ./machines;
      profiles = nixFiles ./profiles;
      mkDarwin =
        name:
        nix-darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            ./modules
            ./machines/${name}.nix
          ];
        };
      # a profile no machine file imports yet (work, until that laptop's name is known) is still
      # evaluated under a synthetic machine, so it cannot rot
      mkProfileCheck =
        name:
        nix-darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            ./modules
            ./profiles/${name}.nix
            {
              networking.hostName = "profile-${name}";
              nixpkgs.hostPlatform = "aarch64-darwin";
            }
          ];
        };
      linux = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      darwinConfigurations = lib.genAttrs names mkDarwin;
      formatter = lib.genAttrs linux (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      # a Mac's closure builds only on a Mac; forcing the full evaluation here means an option
      # typo, an unaccounted flag or a failed assertion fails `nix flake check` on a Linux runner.
      # The dotfiles namespace is forced too, because `task show` and friends read all of it.
      checks = lib.genAttrs linux (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        lib.mapAttrs' (
          name: host:
          lib.nameValuePair "darwin-${name}" (
            pkgs.runCommand "dotfiles-eval-${name}" { } ''
              echo ${builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath} > $out
              echo ${builtins.hashString "sha256" (builtins.toJSON host.config.dotfiles)} >> $out
            ''
          )
        ) (self.darwinConfigurations // lib.genAttrs profiles mkProfileCheck)
      );
    };
}
