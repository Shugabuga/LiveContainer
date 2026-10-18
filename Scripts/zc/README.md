# Building on Linux

These scripts build an unsigned LiveContainer IPA on Linux without Xcode. They
follow the Release configuration of `LiveContainer.xcodeproj` and read
`project.pbxproj` for bundle IDs, versions and Info.plist settings, so the Xcode
project stays the reference.

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
| `ZC_JOBS` | number of CPUs | Parallel compile jobs |

For example, a build without extensions under another bundle ID:

```sh
ZC_BUNDLE_ID=com.example.app ZC_EXTENSIONS=0 ZC_DISPLAY_NAME="Test" \
ZC_IPA_NAME=Test.ipa Scripts/zc/build.sh
```

The IPA is unsigned. Sign it when installing it (Zeus, `xtool install` or another
sideloader). Objects, logs and the staged app are kept in `build/zc/<name>/`.

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
- `check.py`: checks the bundle layout, every Mach-O (arm64, minimum iOS, SDK
  version, embedded dependencies, symbols looked up by name), the Info.plists and
  the string tables. `build.sh` runs it on every build.
- `sign-adhoc.sh`, `verify_sig.py` and `tools/zsign-adhoc.cpp`: ad-hoc sign a copy
  of an IPA with zsign built for Linux (`ZC_ZSIGN_SRC` names zsign's `src/`
  folder), then check every code signature and CodeResources seal. Only a test:
  never install or share the ad-hoc copy.
- `gen/ViewAppIntent.swift`: what Xcode generates from
  `LiveContainerSwiftUI/ViewApp.intentdefinition`.
- `macho.py`: the small Mach-O reader the checks share.

## Differences from an Xcode build

- No asset catalog compiler: the app icon is a set of loose PNGs (no dark or
  tinted variants), and the asset catalog colors are missing, so the code's system
  color fallbacks are used.
- No `Metadata.appintents`, so Shortcuts doesn't see LaunchAppExtension's action.
- The ViewApp intent code comes from `gen/ViewAppIntent.swift`.
- The official CI removes SideStoreSupport from `LiveContainer.ipa` and only ships
  it in the SideStore variant; this build keeps it unless `ZC_EXTENSIONS=0`.
