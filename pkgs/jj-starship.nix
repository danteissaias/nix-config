{
  lib,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "jj-starship";
  version = "0.3.3";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-DM8RtvPP1Kj8y2cy1PkciwBwRjxpbbWltU6zNrPXbJw=";
  };

  cargoHash = "sha256-YpNtAVn+yG1xfj30hkAWpXWMyc6KvTIgMfcBJlFaZnU=";

  meta = {
    homepage = "https://github.com/dmmulroy/jj-starship";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "jj-starship";
  };
}
