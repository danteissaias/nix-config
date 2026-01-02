{
  lib,
  buildNpmPackage,
  nodejs,
}:

buildNpmPackage {
  pname = "global-npm-packages";
  version = "1.0.0";

  src = ../global;

  npmDepsHash = lib.strings.fileContents ../global/deps.hash;

  dontNpmBuild = true;
  dontAutoPatchelf = true;

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r node_modules $out/

    if [ -f $out/node_modules/opencode-ai/postinstall.mjs ]; then
      pushd $out/node_modules/opencode-ai >/dev/null
      NODE_PATH=$out/node_modules ${nodejs}/bin/node postinstall.mjs
      popd >/dev/null
    fi

    # Symlink all binaries from node_modules/.bin
    if [ -d node_modules/.bin ]; then
      for bin in node_modules/.bin/*; do
        if [ -f "$bin" ]; then
          ln -s $out/node_modules/.bin/$(basename $bin) $out/bin/$(basename $bin)
        fi
      done
    fi

    runHook postInstall
  '';

  meta = {
    description = "Global npm packages from /etc/nix-darwin/global";
    platforms = lib.platforms.all;
  };
}
