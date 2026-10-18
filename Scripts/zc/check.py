#!/usr/bin/env python3
"""Checks a built LiveContainer.app (or an .ipa holding one) without Apple tools.
build.sh runs it on every build; run it by hand on an IPA with the same settings
the build used, e.g.

    ZC_BUNDLE_ID=com.example.app ZC_EXTENSIONS=0 Scripts/zc/check.py build/zc/X.ipa

What it checks:
- layout: the frameworks, extensions and resources that should be in the bundle
  (and none of the extensions when ZC_EXTENSIONS=0), and no headers left in it;
- every Mach-O we build is arm64 iOS with minos ZC_MIN_IOS and sdk ZC_SDK_VERSION
  (the prebuilt OpenSSL and CydiaSubstrate are listed but not judged);
- every @rpath dependency is embedded, and the symbols looked up by name at run
  time are exported (LiveContainerMain, the SwiftUI app's main, ZSigner);
- every Info.plist parses and has the keys iOS needs, with no $(...) left, the
  bundle IDs expected for this variant, and LiveProcess's permission strings;
- the compiled string tables parse and every language has every key.

Pass --signed for a signed copy, where _CodeSignature folders are expected.
"""
import argparse
import os
import plistlib
import re
import shutil
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True  # keep __pycache__ out of the source tree
sys.path.insert(0, HERE)
import macho  # noqa: E402
import pbxproj  # noqa: E402

PREBUILT = ('Frameworks/OpenSSL.framework/', 'Frameworks/CydiaSubstrate.framework/')
ALWAYS = [
    'LiveContainer', 'Info.plist', 'PkgInfo', 'Settings.bundle/Root.plist', 'universal.js',
    'AppIcon.png', 'AppIcon60x60@2x.png', 'AppIcon60x60@3x.png', 'AppIcon76x76@2x~ipad.png',
    'en.lproj/Localizable.strings', 'en.lproj/Localizable.stringsdict', 'en.lproj/InfoPlist.strings',
    'Frameworks/LiveContainerShared.framework/LiveContainerShared',
    'Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI',
    'Frameworks/OpenSSL.framework/OpenSSL', 'Frameworks/CydiaSubstrate.framework/CydiaSubstrate',
    'Frameworks/TweakLoader.dylib', 'Frameworks/TestJITLess.dylib', 'Frameworks/ZSign.dylib',
]
EXTENSIONS = [
    'Frameworks/SideStoreSupport.framework/SideStoreSupport',
    'PlugIns/LiveProcess.appex/LiveProcess',
    'PlugIns/ShareExtension.appex/ShareExtension',
    'PlugIns/LaunchAppExtension.appex/LaunchAppExtension',
]
EXPORTS = {
    'Frameworks/LiveContainerShared.framework/LiveContainerShared': ['_LiveContainerMain'],
    'Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI': ['_main'],
    'Frameworks/ZSign.dylib': ['_OBJC_CLASS_$_ZSigner'],
}
REQUIRED_KEYS = ['CFBundleIdentifier', 'CFBundleExecutable', 'CFBundlePackageType', 'CFBundleInfoDictionaryVersion',
                 'CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleSupportedPlatforms', 'MinimumOSVersion',
                 'UIDeviceFamily']


class Checker:
    def __init__(self, app, args):
        self.app, self.args = app, args
        self.failures = 0

    def ok(self, message):
        print(f'  ok    {message}')

    def fail(self, message):
        print(f'  FAIL  {message}')
        self.failures += 1

    def expect(self, condition, message, detail=''):
        if condition:
            self.ok(message)
        else:
            self.fail(f'{message}{": " + detail if detail else ""}')
        return condition

    def files(self):
        for root, dirs, files in os.walk(self.app):
            for f in files:
                path = os.path.join(root, f)
                yield os.path.relpath(path, self.app), path

    def layout(self):
        print('layout')
        want_ext = self.args.extensions == '1'
        missing = [p for p in ALWAYS + (EXTENSIONS if want_ext else []) if not os.path.isfile(os.path.join(self.app, p))]
        self.expect(not missing, f'{len(ALWAYS) + (len(EXTENSIONS) if want_ext else 0)} expected files present',
                    ', '.join(missing))
        if not want_ext:
            present = [p for p in EXTENSIONS if os.path.exists(os.path.join(self.app, os.path.dirname(p)))]
            present += [d for d in ('PlugIns', 'Extensions') if os.path.exists(os.path.join(self.app, d))]
            self.expect(not present, 'no extensions or SideStoreSupport (ZC_EXTENSIONS=0)', ', '.join(present))
        leftovers = []
        for root, dirs, _ in os.walk(self.app):
            for d in dirs:
                if d in ('Headers', 'PrivateHeaders', 'Modules') or (d == '_CodeSignature' and not self.args.signed):
                    leftovers.append(os.path.relpath(os.path.join(root, d), self.app))
        stray = [rel for rel, _ in self.files() if rel.endswith(('.o', '.log', '.swiftmodule', '.h', '.d'))]
        self.expect(not leftovers and not stray, 'no headers, modules, signatures or build leftovers',
                    ', '.join(leftovers + stray))

    def binaries(self):
        print('Mach-O')
        frameworks = set(os.listdir(os.path.join(self.app, 'Frameworks')))
        built = 0
        for rel, path in sorted(self.files()):
            if not macho.is_macho(path):
                continue
            for image in macho.images(path):
                bv = image.build_version
                if rel.startswith(PREBUILT):
                    self.ok(f'{rel}: prebuilt, {bv[0]} minos {bv[1]} sdk {bv[2]}' if bv else f'{rel}: prebuilt')
                    continue
                built += 1
                expected = ('iOS', self.args.min_ios, self.args.sdk)
                if image.cputype != macho.CPU_ARM64 or bv != expected:
                    self.fail(f'{rel}: cpu {image.cputype:#x}, {bv}, expected arm64 {expected}')
                if image.signature and not self.args.signed:
                    self.fail(f'{rel}: has a code signature in an unsigned build')
                for dep in image.dylibs:
                    if dep.startswith('@rpath/') and dep.split('/')[1] not in frameworks:
                        self.fail(f'{rel}: links {dep}, which is not in Frameworks/')
                if image.filetype == 2 and not image.has_main:
                    self.fail(f'{rel}: executable without LC_MAIN')
                for symbol in EXPORTS.get(rel, []):
                    self.expect(symbol in image.exports(), f'{rel} exports {symbol}')
        self.expect(built > 0, f'{built} binaries built here: arm64, iOS minos {self.args.min_ios}, sdk {self.args.sdk}, '
                    'embedded @rpath dependencies, executables have LC_MAIN')

    def plists(self):
        print('Info.plist')
        app_info = None
        repo = os.environ.get('ZC_REPO') or os.path.abspath(os.path.join(HERE, '..', '..'))
        for rel, path in sorted(self.files()):
            if os.path.basename(rel) != 'Info.plist':
                continue
            bundle = os.path.dirname(rel)
            try:
                with open(path, 'rb') as f:
                    info = plistlib.load(f)
            except Exception as e:  # noqa: BLE001
                self.fail(f'{rel}: does not parse ({e})')
                continue
            if rel.startswith(PREBUILT):
                continue
            problems = [k for k in REQUIRED_KEYS if k not in info]
            if info.get('MinimumOSVersion') != self.args.min_ios:
                problems.append(f'MinimumOSVersion={info.get("MinimumOSVersion")}')
            if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
                problems.append('CFBundleSupportedPlatforms')
            exe = os.path.join(self.app, bundle, info.get('CFBundleExecutable', ''))
            if not macho.is_macho(exe):
                problems.append(f'CFBundleExecutable {info.get("CFBundleExecutable")} is not a Mach-O')
            if re.search(r'\$[({][A-Za-z_]', repr(info)):
                problems.append('unresolved $(...)')
            if bundle.endswith('.appex'):
                name = os.path.basename(bundle)[:-6]
                if info.get('CFBundleIdentifier') != f'{self.args.bundle_id}.{name}':
                    problems.append(f'CFBundleIdentifier={info.get("CFBundleIdentifier")}')
                if 'NSExtension' not in info and 'EXAppExtensionAttributes' not in info:
                    problems.append('no NSExtension')
                if name == 'LiveProcess':
                    settings = pbxproj.Project(repo).settings('LiveProcess')
                    wanted = [k[len('INFOPLIST_KEY_'):] for k in settings.keys()
                              if k.startswith('INFOPLIST_KEY_') and k.endswith('UsageDescription')]
                    lacking = [k for k in wanted if k not in info]
                    problems += [f'missing {k}' for k in lacking]
                    if not lacking:
                        self.ok(f'{rel}: all {len(wanted)} permission strings from project.pbxproj')
            if bundle == '':
                app_info = info
            self.expect(not problems, f'{rel}: {info.get("CFBundleIdentifier")} {info.get("CFBundleShortVersionString")}'
                        f' ({info.get("CFBundleVersion")})', ', '.join(problems))
        if app_info is None:
            return self.fail('Info.plist: missing')
        self.expect(app_info.get('CFBundleIdentifier') == self.args.bundle_id, f'app bundle ID {self.args.bundle_id}',
                    str(app_info.get('CFBundleIdentifier')))
        name = self.args.display_name or 'LiveContainer'
        self.expect(app_info.get('CFBundleDisplayName') == name, f'display name "{name}"',
                    str(app_info.get('CFBundleDisplayName')))
        self.expect(str(app_info.get('LCVersionInfo', '')).startswith('Release ('), f'LCVersionInfo "{app_info.get("LCVersionInfo")}"')
        icons = app_info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconFiles', [])
        icons += app_info.get('CFBundleIcons~ipad', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconFiles', [])
        icons.append(app_info.get('CFBundleIconFile', ''))
        names = os.listdir(self.app)
        lacking = [i for i in icons if not any(n.startswith(i) and n.endswith('.png') for n in names)]
        self.expect(icons and not lacking and 'CFBundleIconName' not in app_info,
                    f'icons {sorted(set(icons))} are loose PNGs', ', '.join(lacking))

    def strings(self):
        print('localization')
        tables = {}
        for entry in sorted(os.listdir(self.app)):
            path = os.path.join(self.app, entry, 'Localizable.strings')
            if entry.endswith('.lproj') and os.path.isfile(path):
                with open(path, 'rb') as f:
                    tables[entry[:-6]] = set(plistlib.load(f))
                dict_path = path + 'dict'
                if os.path.isfile(dict_path):
                    with open(dict_path, 'rb') as f:
                        tables[entry[:-6]] |= set(plistlib.load(f))
        if not self.expect('en' in tables, 'en.lproj/Localizable.strings'):
            return
        short = {lang: len(tables['en'] - keys) for lang, keys in tables.items() if tables['en'] - keys}
        self.expect(not short, f'{len(tables)} languages, each with all {len(tables["en"])} keys', str(short))
        infoplist = [e for e in os.listdir(self.app) if os.path.isfile(os.path.join(self.app, e, 'InfoPlist.strings'))]
        self.ok(f'{len(infoplist)} InfoPlist.strings')


def main():
    env = os.environ
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('path', help='LiveContainer.app or an .ipa')
    parser.add_argument('--bundle-id', default=env.get('ZC_BUNDLE_ID', 'com.kdt.livecontainer'))
    parser.add_argument('--extensions', default=env.get('ZC_EXTENSIONS', '1'), choices=['0', '1'])
    parser.add_argument('--display-name', default=env.get('ZC_DISPLAY_NAME', ''))
    parser.add_argument('--min-ios', default=env.get('ZC_MIN_IOS', '17.0'))
    parser.add_argument('--sdk', default=env.get('ZC_SDK_VERSION'), required='ZC_SDK_VERSION' not in env)
    parser.add_argument('--signed', action='store_true', help='expect code signatures')
    args = parser.parse_args()

    tmp = None
    app = args.path
    if app.endswith('.ipa'):
        tmp = tempfile.mkdtemp(prefix='zc-check-')
        with zipfile.ZipFile(app) as z:
            z.extractall(tmp)
        apps = [e for e in os.listdir(os.path.join(tmp, 'Payload')) if e.endswith('.app')]
        if len(apps) != 1:
            sys.exit(f'error: {app} should hold one Payload/*.app, has {apps}')
        app = os.path.join(tmp, 'Payload', apps[0])
    try:
        print(f'Checking {args.path}')
        checker = Checker(os.path.abspath(app), args)
        checker.layout()
        checker.binaries()
        checker.plists()
        checker.strings()
    finally:
        if tmp:
            shutil.rmtree(tmp)
    if checker.failures:
        sys.exit(f'error: {checker.failures} check(s) failed')
    print('All checks passed')


if __name__ == '__main__':
    main()
