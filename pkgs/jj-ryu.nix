{
  lib,
  rustPlatform,
  fetchCrate,
  jujutsu,
}:

rustPlatform.buildRustPackage rec {
  pname = "jj-ryu";
  version = "0.0.1-alpha.8";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-GJl6Yn1nGAFLQE46Q0oMdx/Kl5ghOXqJ0FC3hrR7Veg=";
  };

  cargoHash = "sha256-uKAQ3yuPIO4nXKUCuMSjqQCQ0WEWKlBWJtuaA60jGvA=";

  nativeCheckInputs = [ jujutsu ];

  meta = {
    homepage = "https://github.com/dmmulroy/jj-ryu";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "ryu";
  };
}
