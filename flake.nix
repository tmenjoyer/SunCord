{
  description = "Suncord - Everything Discord doesn't build, we create";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        suncordPkg = pkgs.callPackage ./default.nix { };

        # Wraps official Discord binaries with Suncord desktop patcher
        wrapDiscord = discordPkg: pkgs.runCommand "${discordPkg.name}-suncord" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          meta = discordPkg.meta // {
            description = "${discordPkg.meta.description or "Discord"} (with Suncord mod)";
            mainProgram = discordPkg.meta.mainProgram or "discord";
          };
        } ''
          mkdir -p $out
          cp -rs --no-preserve=mode,ownership ${discordPkg}/* $out/

          for res in $out/opt/*/resources $out/share/*/resources $out/opt/discord*/resources $out/lib/*/resources; do
            if [ -d "$res" ]; then
              rm -rf "$res/app"
              mkdir -p "$res/app"
              cat << 'EOF' > "$res/app/package.json"
{
  "name": "discord",
  "main": "index.js"
}
EOF
              echo 'require("${suncordPkg}/share/suncord/patcher.js");' > "$res/app/index.js"
            fi
          done
        '';
      in rec {
        packages = {
          # The core Suncord compiled desktop JS/CSS files
          suncord = suncordPkg;

          # Pre-wrapped Discord clients
          discord-suncord = wrapDiscord pkgs.discord;
          discord-ptb-suncord = wrapDiscord pkgs.discord-ptb;
          discord-canary-suncord = wrapDiscord pkgs.discord-canary;

          # Default runnable package
          default = packages.discord-suncord;
        };

        apps = rec {
          default = discord;
          discord = flake-utils.lib.mkApp {
            drv = packages.discord-suncord;
          };
          discord-ptb = flake-utils.lib.mkApp {
            drv = packages.discord-ptb-suncord;
          };
          discord-canary = flake-utils.lib.mkApp {
            drv = packages.discord-canary-suncord;
          };
        };
      }
    ) // {
      overlays.default = final: prev: {
        suncord = final.callPackage ./default.nix { };

        discord-suncord = final.runCommand "discord-suncord" {
          nativeBuildInputs = [ final.makeWrapper ];
        } ''
          mkdir -p $out
          cp -rs --no-preserve=mode,ownership ${final.discord}/* $out/
          for res in $out/opt/*/resources $out/share/*/resources $out/opt/discord*/resources $out/lib/*/resources; do
            if [ -d "$res" ]; then
              rm -rf "$res/app"
              mkdir -p "$res/app"
              echo '{"name":"discord","main":"index.js"}' > "$res/app/package.json"
              echo 'require("${final.suncord}/share/suncord/patcher.js");' > "$res/app/index.js"
            fi
          done
        '';

        # Default discord package override
        discord = final.discord-suncord;
      };

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.suncord;
        in {
          options.programs.suncord = {
            enable = lib.mkEnableOption "Suncord Discord client mod";
            channel = lib.mkOption {
              type = lib.types.enum [ "stable" "ptb" "canary" ];
              default = "stable";
              description = "The Discord release channel to use with Suncord.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default =
                if cfg.channel == "canary" then self.packages.${pkgs.system}.discord-canary-suncord
                else if cfg.channel == "ptb" then self.packages.${pkgs.system}.discord-ptb-suncord
                else self.packages.${pkgs.system}.discord-suncord;
              description = "The Suncord-wrapped Discord package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.suncord;
        in {
          options.programs.suncord = {
            enable = lib.mkEnableOption "Suncord Discord client mod";
            channel = lib.mkOption {
              type = lib.types.enum [ "stable" "ptb" "canary" ];
              default = "stable";
              description = "The Discord release channel to use with Suncord.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default =
                if cfg.channel == "canary" then self.packages.${pkgs.system}.discord-canary-suncord
                else if cfg.channel == "ptb" then self.packages.${pkgs.system}.discord-ptb-suncord
                else self.packages.${pkgs.system}.discord-suncord;
              description = "The Suncord-wrapped Discord package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
          };
        };
    };
}
