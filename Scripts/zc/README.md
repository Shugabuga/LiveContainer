# Building on Linux

These scripts build a LiveContainer IPA on Linux without Xcode, matching the
one the official CI builds with Xcode. They follow the Release configuration of
`LiveContainer.xcodeproj` and read `project.pbxproj` for bundle IDs, versions,
entitlements and Info.plist settings, so the Xcode project stays the reference.

## Requirements

- `clang`/`clang++` (LLVM) and `swiftc` (the swift.org Linux toolchain) on `PATH`,
  plus `python3`, `zip`, `llvm-strip` and ImageMagick.
- The Darwin SDK bundle installed by [xtool](https://github.com/xtool-org/xtool)
  (`xtool setup`), by default at `~/.swiftpm/swift-sdks/darwin.artifactbundle`. It
  provides the iPhoneOS SDK, Apple's Swift libraries, `ld64.lld` and the Swift
  macro plugins.
- The submodules: `git submodule update --init --recursive`.

## Building

```sh
Scripts/zc/build.sh
```

builds `build/zc/LiveContainer.ipa` with every extension. Settings come from the
environment (all of them are listed in `env.sh`):

| Variable | Default | Meaning |
| --- | --- | --- |
| `ZC_BUNDLE_ID` | `com.kdt.livecontainer` | Main app bundle ID; extension IDs are derived from it |
| `ZC_EXTENSIONS` | `1` | `0` leaves out every `.appex` and SideStoreSupport |
| `ZC_DISPLAY_NAME` | (from Info.plist) | Home Screen name |
| `ZC_IPA_NAME` | `LiveContainer.ipa` | Output file in `build/zc/` |
| `ZC_MIN_IOS` | `17.0` | Deployment target of every binary |
| `ZC_RECORDED_SDK` | `26.2` | SDK version the binaries and Info.plists record (see below) |
| `ZC_ADHOC_SIGN` | `1` | `0` leaves the IPA unsigned |
| `ZC_JOBS` | number of CPUs | Parallel compile jobs |

For example, a build without extensions under another bundle ID:

```sh
ZC_BUNDLE_ID=com.example.app ZC_EXTENSIONS=0 ZC_DISPLAY_NAME="Test" \
ZC_IPA_NAME=Test.ipa Scripts/zc/build.sh
```

Like the official IPA, the build is ad-hoc signed the way Xcode signs an archive
without a signing identity: each binary has a certificate-less signature, and the
app and its extensions carry their targets' entitlements (app groups, keychain
groups, increased memory limit). Those can't be installed as they are; sign the
IPA when installing it (Zeus, `xtool install` or another sideloader). xtool,
SideStore and AltStore read the entitlements from the executables to decide what
to register, so an unsigned build (`ZC_ADHOC_SIGN=0`) would install without them.
Objects, logs and the staged app are kept in `build/zc/<name>/`.

## Files

- `env.sh`: finds the toolchain and holds the settings above.
- `build.sh`: compiles each product from its source folders in parallel, links,
  strips like an Xcode archive, then calls the scripts below and zips the IPA.
- `assemble.py`: Info.plists, resources, the string catalog (`.strings` and
  `.stringsdict` per language, English filling gaps), loose icon PNGs and the
  prebuilt OpenSSL and CydiaSubstrate frameworks.
- `pbxproj.py`: reads the Xcode project. `pbxproj.py check` compares it with
  `pbxproj-snapshot.txt`; `build.sh` stops when they differ, since a project change
  this build doesn't copy would only show up as a crash on a device. After looking
  at what changed upstream (and updating `build.sh` or `assemble.py` to match), run
  `python3 Scripts/zc/pbxproj.py snapshot > Scripts/zc/pbxproj-snapshot.txt`.
- `codesign.py`: the ad-hoc signing. It signs innermost first, seals each
  bundle's files in `_CodeSignature/CodeResources` with Apple's iOS rules, fills
  in each target's `CODE_SIGN_ENTITLEMENTS` file with the Release settings, and
  leaves `TestJITLess.dylib` unsigned, as Xcode does for a dylib embedded without
  "Code Sign On Copy". Run on the files of the official IPA, it reproduces
  Xcode's signatures and CodeResources byte for byte (at Xcode's page size).
- `check.py`: checks the bundle layout, every Mach-O (arm64, minimum iOS, SDK
  version, embedded dependencies, the libraries loaded at launch, extension entry
  points, symbols looked up by name, signatures and entitlements), the
  Info.plists, the App Intents metadata and the string tables. `build.sh` runs it
  on every build.
- `verify_sig.py`: checks every code signature and CodeResources seal against the
  files they cover. `build.sh` runs it on every signed build.
- `sign-adhoc.sh` and `tools/zsign-adhoc.cpp`: re-sign a copy of an IPA with
  zsign built for Linux (`ZC_ZSIGN_SRC` names zsign's `src/` folder), the signer
  Zeus uses, then run `verify_sig.py` on it. Only a test of re-signing: never
  install or share that copy.
- `gen/ViewAppIntent.swift`: what Xcode generates from
  `LiveContainerSwiftUI/ViewApp.intentdefinition`.
- `gen/LaunchAppExtension/Metadata.appintents`: the App Intents metadata Xcode
  extracts from LaunchAppExtension's Swift code, which Shortcuts reads to list
  its "Launch App" action. No Linux tool can extract it, so it is kept by hand;
  `sources.sha256` records the code it describes, and `build.sh` stops when that
  code changes. After updating the metadata, run
  `sha256sum LaunchAppExtension/*.swift > Scripts/zc/gen/LaunchAppExtension/sources.sha256`.
- `macho.py`: the small Mach-O reader the other scripts share.

## Differences from an Xcode build

- The headers and Swift modules come from the SDK in the bundle (iOS 27.1), but
  every binary and Info.plist records `ZC_RECORDED_SDK`, the SDK of the official
  build (Xcode 26.2). iOS picks "linked on or after" behavior by the main
  executable's SDK, for LiveContainer and for every guest app that doesn't spoof
  its own, so a newer SDK would change how guest apps run (for example, apps
  built with the SDK after iOS 26 must adopt UIScene). Liquid Glass needs 26 or
  later.
- No asset catalog compiler: the app icon is a set of loose PNGs (no dark or
  tinted variants), and the asset catalog colors are missing, so the code's system
  color fallbacks are used.
- The ViewApp intent code comes from `gen/ViewAppIntent.swift`, which declares
  only what `AppDelegate.swift` uses. It matters only in the SideStore variant,
  the one that lists the intent in `INIntentsSupported`, which this build doesn't
  make.
- Signatures use 4 KiB pages everywhere; Xcode uses 16 KiB for the Swift
  extensions. iOS accepts both, and installing replaces them.
- The official CI removes SideStoreSupport from `LiveContainer.ipa` and only ships
  it in the SideStore variant; this build keeps it unless `ZC_EXTENSIONS=0`.
