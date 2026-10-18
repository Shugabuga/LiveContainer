# Toolchain and build settings for the Linux build. build.sh and sign-adhoc.sh
# source this file; it is not meant to be run on its own.
#
# Needs: clang, clang++ and swiftc on PATH (LLVM clang and the swift.org Linux
# toolchain), python3, zip, ImageMagick (magick or convert), and the Darwin SDK
# bundle that xtool installs (`xtool setup`), which provides the iPhoneOS SDK,
# Apple's Swift resources, ld64.lld and the macro plugins.
#
# Everything below can be overridden from the environment.

# Variant of the app to build.
: "${ZC_BUNDLE_ID:=app.reiko.zcontainer}"    # main app; extension IDs are derived from it
: "${ZC_EXTENSIONS:=1}"                       # 0 leaves out every .appex
: "${ZC_DISPLAY_NAME:=}"                      # empty keeps CFBundleDisplayName from Info.plist
# URL scheme the app declares first and builds its own links with. Zeus opens
# zContainer by "zcontainer", so only a build that must sit next to zContainer on
# one iPhone takes another (for example zcontainer-test).
: "${ZC_URL_SCHEME:=zcontainer}"
: "${ZC_IPA_NAME:=zContainer.ipa}"            # file name of the IPA in $ZC_BUILD_DIR
: "${ZC_MIN_IOS:=17.0}"                       # deployment target of every binary we build
# SDK version the binaries record (LC_BUILD_VERSION) and Info.plist names. iOS
# turns on "linked on or after" behavior by it, for zContainer's own UI and for
# every guest app that doesn't spoof its own SDK, so it stays at what the official
# build uses (Xcode 26.2) rather than the newer SDK the headers come from.
: "${ZC_RECORDED_SDK:=26.2}"
: "${ZC_ADHOC_SIGN:=1}"                       # 1 ad-hoc signs with entitlements like Xcode's archive; 0 leaves it unsigned

ZC_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${ZC_REPO:=$(cd "$ZC_SCRIPTS/../.." && pwd)}"
: "${ZC_BUILD_DIR:=$ZC_REPO/build/zc}"
: "${ZC_JOBS:=$(nproc 2>/dev/null || echo 4)}"

: "${ZC_SDK_BUNDLE:=$HOME/.swiftpm/swift-sdks/darwin.artifactbundle}"
: "${CLANG:=clang}"
: "${CLANGXX:=clang++}"
: "${SWIFTC:=swiftc}"
: "${PYTHON:=python3}"

zc_die() { echo "error: $*" >&2; exit 1; }

# Newest iPhoneOS SDK in the bundle, unless ZC_SDK names one.
if [[ -z "${ZC_SDK:-}" ]]; then
    ZC_SDK="$(find "$ZC_SDK_BUNDLE/Developer/Platforms/iPhoneOS.platform/Developer/SDKs" -maxdepth 1 \
        -name 'iPhoneOS[0-9]*.sdk' 2>/dev/null | sort -V | tail -n 1)"
fi
[[ -n "$ZC_SDK" && -f "$ZC_SDK/SDKSettings.json" ]] ||
    zc_die "no iPhoneOS SDK found in $ZC_SDK_BUNDLE (install it with xtool setup, or set ZC_SDK_BUNDLE or ZC_SDK)"
ZC_SDK_VERSION="$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["Version"])' "$ZC_SDK/SDKSettings.json")"

ZC_TOOLCHAIN="$ZC_SDK_BUNDLE/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib"
# The unwrapped linker: the wrapper next to it turns -r links into archives, and the
# system ld64.lld can't read the SDK's .tbd stubs.
ZC_LD="$ZC_SDK_BUNDLE/toolset/bin/orig/ld64.lld"
# Compiler runtime with ___isPlatformVersionAtLeast, which @available needs.
ZC_CLANG_RT="$(ls "$ZC_TOOLCHAIN"/clang/*/lib/darwin/libclang_rt.ios.a 2>/dev/null | sort -V | tail -n 1)"
ZC_SWIFT_RESOURCES="$ZC_TOOLCHAIN/swift"
ZC_MACROS="$ZC_SDK_BUNDLE/OpenAppleMacrosServer"
# Swift's own macros (@Observable) come from the Linux toolchain's plugins; the
# bundle has only Apple's macOS builds of them, and OpenAppleMacrosServer only
# stands in for SwiftUI's and App Intents'.
: "${ZC_SWIFT_PLUGINS:=$(dirname "$(readlink -f "$(command -v "$SWIFTC")")")/../lib/swift/host/plugins}"
ZC_OPENSSL="$ZC_REPO/OpenSSL/Frameworks/iphoneos"

for tool in "$CLANG" "$CLANGXX" "$SWIFTC" "$PYTHON" zip llvm-strip; do
    command -v "$tool" >/dev/null || zc_die "$tool is not on PATH"
done
command -v magick >/dev/null || command -v convert >/dev/null || zc_die "ImageMagick (magick or convert) is not on PATH"
[[ -x "$ZC_LD" ]] || zc_die "missing linker $ZC_LD"
[[ -f "$ZC_CLANG_RT" ]] || zc_die "missing libclang_rt.ios.a under $ZC_TOOLCHAIN/clang"
[[ -d "$ZC_SWIFT_RESOURCES/iphoneos" ]] || zc_die "missing Swift resources in $ZC_SWIFT_RESOURCES"
[[ -x "$ZC_MACROS" ]] || zc_die "missing macro plugin server $ZC_MACROS"
[[ -f "$ZC_SWIFT_PLUGINS/libObservationMacros.so" ]] ||
    zc_die "missing libObservationMacros.so in $ZC_SWIFT_PLUGINS (set ZC_SWIFT_PLUGINS to the toolchain's lib/swift/host/plugins)"
[[ -f "$ZC_OPENSSL/OpenSSL.framework/OpenSSL" ]] ||
    zc_die "OpenSSL submodule is not checked out (git submodule update --init --recursive)"
[[ -f "$ZC_REPO/litehook/src/litehook.c" ]] ||
    zc_die "litehook submodule is not checked out (git submodule update --init --recursive)"
[[ "$ZC_EXTENSIONS" == 0 || "$ZC_EXTENSIONS" == 1 ]] || zc_die "ZC_EXTENSIONS must be 0 or 1"
[[ "$ZC_ADHOC_SIGN" == 0 || "$ZC_ADHOC_SIGN" == 1 ]] || zc_die "ZC_ADHOC_SIGN must be 0 or 1"
[[ "$ZC_RECORDED_SDK" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || zc_die "ZC_RECORDED_SDK '$ZC_RECORDED_SDK' is not a version"
[[ "$(printf '%s\n' "$ZC_RECORDED_SDK" "$ZC_SDK_VERSION" | sort -V | tail -n 1)" == "$ZC_SDK_VERSION" ]] ||
    zc_die "ZC_RECORDED_SDK $ZC_RECORDED_SDK is newer than the SDK in use ($ZC_SDK_VERSION)"
[[ "$ZC_BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || zc_die "ZC_BUNDLE_ID '$ZC_BUNDLE_ID' is not a valid bundle ID"
[[ "$ZC_URL_SCHEME" =~ ^[a-z][a-z0-9.+-]*$ && "$ZC_URL_SCHEME" != *livecontainer* && "$ZC_URL_SCHEME" != zeus ]] ||
    zc_die "ZC_URL_SCHEME '$ZC_URL_SCHEME' must be a lowercase URL scheme, and not LiveContainer's or Zeus's"
[[ "$ZC_IPA_NAME" =~ ^[A-Za-z0-9._+-]+\.ipa$ && ! "$ZC_IPA_NAME" =~ ^(cache|tools|adhoc)\.ipa$ ]] ||
    zc_die "ZC_IPA_NAME '$ZC_IPA_NAME' must be a plain file name ending in .ipa"

export ZC_BUNDLE_ID ZC_EXTENSIONS ZC_DISPLAY_NAME ZC_URL_SCHEME ZC_IPA_NAME ZC_MIN_IOS ZC_RECORDED_SDK ZC_ADHOC_SIGN \
    ZC_REPO ZC_BUILD_DIR ZC_SDK ZC_SDK_VERSION ZC_OPENSSL
