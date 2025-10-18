{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "global-npm-packages";
  version = "1.0.0";

  src = ../global;

  npmDepsHash = lib.strings.fileContents ../global/deps.hash;

  dontNpmBuild = true;
  dontAutoPatchelf = true;

  installPhase = ''
    mkdir -p $out/bin
    cp -r node_modules $out/

    # Symlink all binaries from node_modules/.bin
    if [ -d node_modules/.bin ]; then
      for bin in node_modules/.bin/*; do
        if [ -f "$bin" ]; then
          ln -s $out/node_modules/.bin/$(basename $bin) $out/bin/$(basename $bin)
        fi
      done
    fi
  '';

  meta = {
    description = "Global npm packages from /etc/nix-darwin/global";
    platforms = lib.platforms.all;
  };
}
