{ stdenv }:

# Tap to click is written to the preferences by nix-darwin, but the trackpad
# driver does not re-read it live on `darwin-rebuild switch`; it only applies
# after a logout/login or a manual toggle in System Settings. System Settings
# applies it live through the private MTTGestureBackEnd class in
# PreferencePanesSupport. This tiny tool does the same call.
#
# Usage: reload-tap-to-click [0|1]
#   argument overrides the value; otherwise the per-host NSGlobalDomain
#   com.apple.mouse.tapBehavior is used, defaulting to 1 (enabled).

stdenv.mkDerivation {
  pname = "reload-tap-to-click";
  version = "1.0.0";
  dontUnpack = true;

  buildPhase = ''
    cat > main.m << 'EOF'
    #import <Foundation/Foundation.h>
    #import <CoreFoundation/CoreFoundation.h>
    #import <objc/message.h>
    #import <dlfcn.h>
    int main(int argc, char **argv) {
      dlopen("/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW);
      Class c = NSClassFromString(@"MTTGestureBackEnd");
      if (!c) { fprintf(stderr, "MTTGestureBackEnd not found\n"); return 1; }
      id be = [c performSelector:@selector(sharedInstance)];
      long long desired = 1;
      if (argc > 1) {
        desired = atoll(argv[1]);
      } else {
        CFPropertyListRef v = CFPreferencesCopyValue(CFSTR("com.apple.mouse.tapBehavior"),
          kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        if (v && CFGetTypeID(v) == CFNumberGetTypeID()) {
          int t; CFNumberGetValue((CFNumberRef)v, kCFNumberIntType, &t); desired = t;
        }
      }
      // The backend coalesces updates with a delay; disable that so the change
      // is pushed to the driver immediately instead of after this process exits.
      if ([be respondsToSelector:@selector(setAllowToCoalesce:)])
        ((void(*)(id, SEL, BOOL))objc_msgSend)(be, @selector(setAllowToCoalesce:), NO);
      if ([be respondsToSelector:@selector(setUpdateDelay:)])
        ((void(*)(id, SEL, double))objc_msgSend)(be, @selector(setUpdateDelay:), 0.0);
      ((void(*)(id, SEL, long long))objc_msgSend)(be, @selector(setTapBehavior:), desired);
      // Let any coalesced/async update block fire before we exit.
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.7]];
      return 0;
    }
    EOF
    $CC -O2 main.m -o reload-tap-to-click \
      -framework Foundation -framework CoreFoundation
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp reload-tap-to-click $out/bin/
  '';

  meta.platforms = [ "aarch64-darwin" ];
}
