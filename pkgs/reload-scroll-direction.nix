{ stdenv, swift }:

stdenv.mkDerivation {
  pname = "reload-scroll-direction";
  version = "1.0.0";
  dontUnpack = true;

  buildPhase = ''
    cat > main.swift << 'EOF'
    import Foundation
    @_silgen_name("setSwipeScrollDirection")
    func setSwipeScrollDirection(_ natural: Bool)
    setSwipeScrollDirection(UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection"))
    EOF
    ${swift}/bin/swiftc -O main.swift -o reload-scroll-direction \
      -F /System/Library/PrivateFrameworks -framework PreferencePanesSupport
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp reload-scroll-direction $out/bin/
  '';

  meta.platforms = [ "aarch64-darwin" ];
}
