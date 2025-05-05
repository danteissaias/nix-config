{
  lib,
  requireFile,
  stdenvNoCC,
  unzip,
  variant ? "ligaturesoff-0variant0-7variant0",
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "berkeley-mono";
  version = "2.002";

  src = requireFile rec {
    name = "${finalAttrs.pname}-${variant}-${finalAttrs.version}.zip";
    sha256 = "09pf7sv72xkshxjhryva8d9z417awcxzv664v102qn44ri32lm96";
    message = ''
      This file needs to be manually downloaded from the Berkeley Graphics
      site (https://berkeleygraphics.com/accounts). An email will be sent to
      get a download link.

      Select the variant that matches “${variant}”
      & download the zip file.

      Then run:

      mv \$PWD/berkeley-mono-typeface.zip \$PWD/${name}
      nix-prefetch-url --type sha256 file://\$PWD/${name}
    '';
  };

  nativeBuildInputs = [
    unzip
  ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    runHook preInstall
    install -D -m444 -t $out/share/fonts/truetype **/**/*.ttf
    runHook postInstall
  '';

  meta = {
    description = "Berkeley Mono Typeface";
    homepage = "https://berkeleygraphics.com/typefaces/berkeley-mono";
    changelog = "https://usgraphics.com/products/berkeley-mono/releases";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
})
