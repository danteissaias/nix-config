{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation rec {
  pname = "terraform";
  version = "1.14.5";

  src = fetchurl {
    url = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_darwin_arm64.zip";
    hash = "sha256-Ey50ACRjVJSQDlYQFM9NERpmxkVPzVSN7lzEz4c+5S8=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 terraform $out/bin/terraform
    runHook postInstall
  '';

  meta = {
    homepage = "https://www.terraform.io";
    license = lib.licenses.bsl11;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "terraform";
  };
}
