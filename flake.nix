{
  description = "Kakoune overlay — stable releases and nightly git builds of kakoune and its ecosystem";

  nixConfig = {
    extra-substituters = [ "https://kakoune-overlay.cachix.org" ];
    extra-trusted-public-keys = [
      "kakoune-overlay.cachix.org-1:wvzi0bQFg1NEkPF1eaU3atZD/4soGx1IG6sensUdvxY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      overlays.default = import ./overlay.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          overlayed = pkgs.extend self.overlays.default;
        in
        {
          inherit (overlayed)
            kakoune
            kakoune-git
            kakoune-unwrapped
            kakoune-unwrapped-git
            kak-tree-sitter
            kak-tree-sitter-unwrapped
            ;
          inherit (overlayed.kakounePlugins)
            kakoune-lsp
            ;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          overlayed = pkgs.extend self.overlays.default;
        in
        {
          kakoune-tool-dep-smoke-test =
            let
              testPlugin = overlayed.kakouneUtils.buildKakounePlugin {
                pname = "test-plugin-tool-dep";
                version = "0.0.1";
                src = pkgs.writeTextDir "test.kak" "# Test plugin";
                deps = [ "hello" ];
              };
              wrapped = overlayed.wrapKakoune overlayed.kakoune-unwrapped {
                plugins = [ testPlugin ];
              };
            in
            pkgs.runCommand "kakoune-tool-dep-smoke-test" { } ''
              if grep -q "${pkgs.hello.outPath}" ${wrapped}/bin/kak; then
                echo "PASS: wrapper script includes hello"
                touch $out
              else
                echo "FAIL: wrapper script does not include hello"
                echo "Wrapper contents:"
                cat ${wrapped}/bin/kak
                exit 1
              fi
            '';

          kakoune-fzf-kak-smoke-test =
            let
              wrapped = overlayed.wrapKakoune overlayed.kakoune-unwrapped {
                plugins = [ overlayed.kakounePlugins.fzf-kak ];
              };
            in
            pkgs.runCommand "kakoune-fzf-kak-smoke-test" { } ''
              if grep -q "${pkgs.fzf.outPath}" ${wrapped}/bin/kak; then
                echo "PASS: wrapper script includes fzf store path"
                touch $out
              else
                echo "FAIL: wrapper script does not include fzf store path"
                echo "Wrapper contents:"
                cat ${wrapped}/bin/kak
                exit 1
              fi
            '';
        }
      );
    };
}
