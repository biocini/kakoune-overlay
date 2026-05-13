self: super:
let
  inherit (super)
    lib
    fetchFromGitHub
    fetchFromGitLab
    fetchgit
    ;
  inherit (super.kakouneUtils) buildKakounePluginFrom2Nix;

  manifest = lib.importJSON ../repos/plugins/manifest.json;
  overrides = import ../repos/plugins/overrides.nix { pkgs = super; };

  # Map our normalized plugin names to nixpkgs' names where they differ.
  nameMap = {
    active-window = "active-window-kak";
    auto-pairs = "auto-pairs-kak";
    byline = "byline-kak";
    connect = "connect-kak";
    fzf = "fzf-kak";
    kakoune-buffers = "kak-buffers";
    kakoune-extra-filetypes = "kakoune-extra-filetypes";
    openscad = "openscad-kak";
    pandoc = "pandoc-kak";
    powerline = "powerline-kak";
    prelude = "prelude-kak";
    smarttab = "smarttab-kak";
    tabs = "tabs-kak";
  };

  fetchFromRepo =
    name: meta:
    if meta.type == "github" then
      fetchFromGitHub {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "gitlab" then
      fetchFromGitLab {
        inherit (meta) owner repo rev;
        sha256 = meta.sha256;
      }
    else if meta.type == "git" then
      fetchgit {
        inherit (meta) url rev;
        sha256 = meta.sha256;
        fetchSubmodules = meta.fetchSubmodules or false;
        leaveDotGit = meta.leaveDotGit or false;
      }
    else
      throw "Unknown source type '${meta.type}' for plugin ${name}";

  mkPlugin =
    name: meta:
    let
      newSrc = fetchFromRepo name meta;
      override = overrides.${name} or { deps = [ ]; };
      deps = override.deps or [ ];
      bins = override.bins or [ ];
      customPostInstall = override.postInstall or "";

      nixpkgsName = nameMap.${name} or name;
      inNixpkgs = builtins.hasAttr nixpkgsName super.kakounePlugins;

      # Symlink only the explicitly-listed binaries from deps into
      # $out/share/kak/bin/.  The list is determined by reading the
      # plugin's kak files and noting which bare commands appear in
      # %sh{...} blocks.
      symlinkBins = lib.optionalString (bins != [ ]) ''
        mkdir -p $out/share/kak/bin
        for dep in ${lib.concatMapStringsSep " " (d: lib.getBin d) deps}; do
          for bin in ${lib.concatStringsSep " " bins}; do
            if [ -e "$dep/bin/$bin" ] && [ ! -e "$out/share/kak/bin/$bin" ]; then
              ln -sf "$dep/bin/$bin" "$out/share/kak/bin/$bin"
            fi
          done
        done
      '';

      depPostInstall = lib.optionalString (bins != [ ] || customPostInstall != "") ''
        ${symlinkBins}
        ${customPostInstall}
      '';

      homepage =
        meta.homepage or (
          if meta.type == "github" then
            "https://github.com/${meta.owner}/${meta.repo}/"
          else if meta.type == "gitlab" then
            "https://gitlab.com/${meta.owner}/${meta.repo}/"
          else if meta.type == "git" then
            meta.url
          else
            ""
        );
    in
    if inNixpkgs then
      # Plugin exists in nixpkgs: override src and version only.
      # Nixpkgs' own overrides (preFixup, buildInputs, etc.) are preserved.
      super.kakounePlugins.${nixpkgsName}.overrideAttrs (old: {
        version = meta.version;
        src = newSrc;
        meta = (old.meta or { }) // {
          inherit homepage;
        };
      })
    else
      # New plugin: build from scratch with dependency injection
      buildKakounePluginFrom2Nix {
        pname = name;
        version = meta.version;
        src = newSrc;
        propagatedBuildInputs = deps;
        meta.homepage = homepage;
        postInstall = depPostInstall;
      };

  gitPlugins = lib.mapAttrs mkPlugin manifest;

  # For plugins that exist in nixpkgs under a different name, also
  # override the nixpkgs name so users can reference either.
  nixpkgsOverrides = lib.mapAttrs' (
    ourName: nixpkgsName: lib.nameValuePair nixpkgsName gitPlugins.${ourName}
  ) nameMap;

in
{
  kakounePlugins = super.kakounePlugins // gitPlugins // nixpkgsOverrides;
}
