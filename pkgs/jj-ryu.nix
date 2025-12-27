{
  lib,
  rustPlatform,
  fetchCrate,
  jujutsu,
}:

rustPlatform.buildRustPackage rec {
  pname = "jj-ryu";
  version = "0.0.1-alpha.3";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-77ouQNgfnKG8ZNBqRFoGg4kEVejBvqstzGJlvEdGkOg=";
  };

  cargoHash = "sha256-N4rvaoOkf49ovImY/FRTivyLXhzFZU7b5K5m9RiTutY=";

  nativeCheckInputs = [ jujutsu ];

  meta = {
    homepage = "https://github.com/dmmulroy/jj-ryu";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "ryu";
  };
}
