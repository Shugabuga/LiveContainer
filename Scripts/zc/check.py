#!/usr/bin/env python3
"""Checks a built zContainer app (Payload/LiveContainer.app, or an .ipa holding
one) without Apple tools. build.sh runs it on every build; run it by hand on an
IPA with the same settings the build used, e.g.

    ZC_BUNDLE_ID=com.example.app ZC_EXTENSIONS=0 Scripts/zc/check.py build/zc/X.ipa

What it checks:
- layout: the frameworks, extensions and resources that should be in the bundle
  (and none of the extensions when ZC_EXTENSIONS=0), no headers left in it, and
  nothing of SideStore or AltStore in it (file names, Info.plists, entitlements);
- every Mach-O we build is arm64 iOS with minos ZC_MIN_IOS and sdk
  ZC_RECORDED_SDK (the prebuilt OpenSSL and CydiaSubstrate are listed but not
  judged);
- every @rpath dependency is embedded, the main executable loads only libSystem,
  LiveContainerShared and LiveProcess don't load UIKit, every extension starts in
  NSExtensionMain, and the symbols looked up by name at run time are exported
  (LiveContainerMain, the SwiftUI app's main, ZSigner);
- signing (--signing, from ZC_ADHOC_SIGN): "adhoc", the build's own signatures:
  everything Xcode signs is signed, TestJITLess.dylib isn't, and the app and its
  extensions carry their targets' entitlements; "none", an unsigned build;
  "other", a copy re-signed by another tool, where every binary must be signed;
- every Info.plist parses and has the keys iOS needs, with no $(...) left, the
  bundle IDs expected for this variant, the SDK the binaries record, and
  LiveProcess's permission strings; *Dictionary keys the build adds hold
  dictionaries; the main Info.plist carries the ZeusCompanion marker Zeus looks
  for before it hands over its certificate;
- LaunchAppExtension's Metadata.appintents parses;
- the compiled string tables parse, every language has every key, and none of
  them mentions SideStore or AltStore;
- zContainer's identity: the zcontainer URL scheme comes first and no
  livecontainer scheme is declared or queried, the queried schemes are only
  zcontainer and zeus, the name is zContainer, the keychain groups are
  <team>.app.reiko.zcontainer.shared and .1 to .127 and the app group is named
  after the bundle ID, and no user-facing string (string tables, InfoPlist.strings,
  Info.plist values, the Shortcuts action) says LiveContainer, except the About
  page's credits (lc.about.*) and links to LiveContainer's own pages.

verify_sig.py checks the signatures themselves.
"""
import argparse
import json
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
import codesign  # noqa: E402
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
    'PlugIns/LiveProcess.appex/LiveProcess',
    'PlugIns/ShareExtension.appex/ShareExtension',
    'PlugIns/LaunchAppExtension.appex/LaunchAppExtension',
    'PlugIns/LaunchAppExtension.appex/Metadata.appintents/extract.actionsdata',
    'PlugIns/LaunchAppExtension.appex/Metadata.appintents/version.json',
]
# Libraries a binary may load at launch. UIKit has to wait until LCBootstrap has
# set up the guest app, and LiveProcess keeps it from loading at all.
ONLY_LINKS = {'LiveContainer': ['/usr/lib/libSystem.B.dylib']}
UIKIT = '/System/Library/Frameworks/UIKit.framework/UIKit'
NO_UIKIT = ['Frameworks/LiveContainerShared.framework/LiveContainerShared', 'PlugIns/LiveProcess.appex/LiveProcess']
EXPORTS = {
    'Frameworks/LiveContainerShared.framework/LiveContainerShared': ['_LiveContainerMain'],
    'Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI': ['_main'],
    'Frameworks/ZSign.dylib': ['_OBJC_CLASS_$_ZSigner'],
}
# What Zeus checks in the main Info.plist before it puts its certificate in the
# app (ZContainer.isMarked in Zeus); LCZeusCertificate reads that file.
ZEUS_COMPANION = {'Kind': 'zContainer', 'Protocol': 1}
STORES = re.compile(r'(?i)side-?store|alt-?store')
# zContainer's identity. The keychain groups don't follow the bundle ID: they are
# the same for every build, as LiveContainer's are, so a test build under another
# App ID still finds them.
SCHEME = 'zcontainer'
QUERIED_SCHEMES = ['zcontainer', 'zeus']  # its own (canOpenURL on itself) and Zeus's
NAME = 'zContainer'
KEYCHAIN_GROUP = 'app.reiko.zcontainer.shared'
KEYCHAIN_GROUP_COUNT = 128
# The old name, outside URLs and links to LiveContainer's own pages, which may
# keep it (a link to LiveContainer's FAQ is still called that).
OLD_NAME = re.compile(r'(?i)live\s?container')
UPSTREAM_LINK = re.compile(r'\[[^\]]*\]\s*\(https?://(?:github\.com/(?:LiveContainer|khanhduytran0)/LiveContainer|'
                           r'livecontainer\.github\.io)[^)\s]*\)')
URL = re.compile(r'[a-z][a-z0-9+.-]*://[^\s)\]"]+', re.I)
CREDIT_KEYS = 'lc.about.'  # Settings > About zContainer credits LiveContainer by name
REQUIRED_KEYS = ['CFBundleIdentifier', 'CFBundleExecutable', 'CFBundlePackageType', 'CFBundleInfoDictionaryVersion',
                 'CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleSupportedPlatforms', 'MinimumOSVersion',
                 'UIDeviceFamily']


# Info.plist keys people see: the Home Screen name, and the name iOS falls back
# to and says. Usage descriptions are checked too.
VISIBLE_KEYS = ('CFBundleDisplayName', 'CFBundleName', 'CFBundleSpokenName')


def says_old_name(value):
    """Whether a user-facing value (a string, or a plural dictionary) still says
    LiveContainer, leaving out URLs and links to LiveContainer's own pages."""
    return any(OLD_NAME.search(URL.sub('', UPSTREAM_LINK.sub('', text))) for text in strings_in(value))


def strings_in(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings_in(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings_in(v)


class Checker:
    def __init__(self, app, args):
        self.app, self.args = app, args
        self.failures = 0
        self.repo = os.environ.get('ZC_REPO') or os.path.abspath(os.path.join(HERE, '..', '..'))
        self.old_names = []  # user-facing strings that still say LiveContainer
        self.signer = codesign.Signer(self.repo, args.bundle_id)

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
            self.expect(not present, 'no extensions (ZC_EXTENSIONS=0)', ', '.join(present))
        leftovers, unsealed = [], []
        signed = self.args.signing != 'none'
        for root, dirs, _ in os.walk(self.app):
            for d in dirs:
                if d in ('Headers', 'PrivateHeaders', 'Modules') or (d == '_CodeSignature' and not signed):
                    leftovers.append(os.path.relpath(os.path.join(root, d), self.app))
            if signed and root.endswith(codesign.CODE_BUNDLE_SUFFIXES) and \
                    not os.path.isfile(os.path.join(root, '_CodeSignature', 'CodeResources')):
                unsealed.append(os.path.relpath(root, self.app))
        stray = [rel for rel, _ in self.files() if rel.endswith(('.o', '.log', '.swiftmodule', '.h', '.d'))]
        self.expect(not leftovers and not stray, 'no headers, modules, build leftovers'
                    + ('' if signed else ' or signatures'), ', '.join(leftovers + stray))
        if signed:
            self.expect(not unsealed, 'every bundle has _CodeSignature/CodeResources', ', '.join(unsealed))
        stores = [rel for rel, _ in self.files() if STORES.search(rel)]
        for rel, path in self.files():
            if os.path.basename(rel) == 'Info.plist' and not rel.startswith(PREBUILT):
                with open(path, 'rb') as f:
                    if STORES.search(repr(plistlib.load(f))):
                        stores.append(rel)
        for target in sorted(self.signer.targets):
            if STORES.search(repr(self.signer.entitlements(target))):
                stores.append(f'{target} entitlements')
        self.expect(not stores, 'nothing of SideStore or AltStore', ', '.join(stores))

    def main_executables(self):
        """{relative path of a bundle's executable: target name} for every code bundle."""
        out = {}
        for root, _, _ in os.walk(self.app):
            info_path = os.path.join(root, 'Info.plist')
            if (root == self.app or root.endswith(codesign.CODE_BUNDLE_SUFFIXES)) and os.path.isfile(info_path):
                with open(info_path, 'rb') as f:
                    exe = plistlib.load(f).get('CFBundleExecutable', '')
                target = 'LiveContainer' if root == self.app else os.path.splitext(os.path.basename(root))[0]
                out[os.path.relpath(os.path.join(root, exe), self.app)] = target
        return out

    def signature(self, rel, image, target):
        """Checks one slice's signature against --signing; returns a summary."""
        blobs = image.signature_blobs()
        if self.args.signing == 'none':
            if blobs and not rel.startswith(PREBUILT):  # those come with their vendors' signatures
                self.fail(f'{rel}: has a code signature in an unsigned build')
            return None
        if self.args.signing == 'other' or target is None:
            unsigned = os.path.basename(rel) in self.signer.unsigned and self.args.signing == 'adhoc'
            if unsigned and blobs:
                self.fail(f'{rel}: signed, but Xcode leaves it unsigned (no Code Sign On Copy)')
            elif not unsigned and not blobs:
                self.fail(f'{rel}: not signed')
            return 'unsigned' if unsigned else 'signed'
        if not blobs:
            self.fail(f'{rel}: not signed')
            return None
        want = self.signer.entitlements(target)
        have = plistlib.loads(blobs[5][8:]) if 5 in blobs else None
        if have != want:
            if have is None or want is None:
                detail = f'{"no" if have is None else len(have)} entitlements, expected {"none" if want is None else len(want)}'
            else:
                detail = ', '.join(sorted(k for k in set(have) | set(want) if have.get(k) != want.get(k)))
            self.fail(f'{rel}: entitlements differ from {target}\'s CODE_SIGN_ENTITLEMENTS: {detail}')
        elif want is not None and 7 not in blobs:
            self.fail(f'{rel}: no DER entitlements')
        return f'{len(want)} entitlements' if want is not None else 'signed'

    def binaries(self):
        print('Mach-O')
        frameworks = set(os.listdir(os.path.join(self.app, 'Frameworks')))
        executables = self.main_executables()
        built = signed = with_entitlements = 0
        for rel, path in sorted(self.files()):
            if not macho.is_macho(path):
                continue
            for image in macho.images(path):
                bv = image.build_version
                summary = self.signature(rel, image, executables.get(rel))
                signed += summary not in (None, 'unsigned')
                with_entitlements += bool(summary and summary.endswith('entitlements'))
                if rel.startswith(PREBUILT):
                    self.ok(f'{rel}: prebuilt, {bv[0]} minos {bv[1]} sdk {bv[2]}' if bv else f'{rel}: prebuilt')
                    continue
                built += 1
                expected = ('iOS', self.args.min_ios, self.args.sdk)
                if image.cputype != macho.CPU_ARM64 or bv != expected:
                    self.fail(f'{rel}: cpu {image.cputype:#x}, {bv}, expected arm64 {expected}')
                for dep in image.dylibs:
                    if dep.startswith('@rpath/') and dep.split('/')[1] not in frameworks:
                        self.fail(f'{rel}: links {dep}, which is not in Frameworks/')
                if rel in ONLY_LINKS and image.dylibs != ONLY_LINKS[rel]:
                    self.fail(f'{rel}: links {image.dylibs}, expected only {ONLY_LINKS[rel]}')
                if rel in NO_UIKIT and UIKIT in image.dylibs:
                    self.fail(f'{rel}: links UIKit, which must not load at launch')
                if image.filetype == 2 and not image.has_main:
                    self.fail(f'{rel}: executable without LC_MAIN')
                if '.appex/' in rel and image.filetype == 2 and not self.starts_in_extension_main(image):
                    self.fail(f'{rel}: does not start in NSExtensionMain')
                for symbol in EXPORTS.get(rel, []):
                    self.expect(symbol in image.exports(), f'{rel} exports {symbol}')
        self.expect(built > 0, f'{built} binaries built here: arm64, iOS minos {self.args.min_ios}, sdk {self.args.sdk}, '
                    'embedded @rpath dependencies, executables have LC_MAIN, extensions start in NSExtensionMain')
        self.ok(f'links: {", ".join(ONLY_LINKS)} loads only libSystem; {", ".join(NO_UIKIT)} do not load UIKit')
        if self.args.signing != 'none':
            self.ok(f'{signed} binaries signed ({self.args.signing}), {with_entitlements} with their target\'s entitlements'
                    + (f', unsigned as in Xcode: {", ".join(sorted(self.signer.unsigned))}'
                       if self.args.signing == 'adhoc' else ''))

    @staticmethod
    def starts_in_extension_main(image):
        """The entry point is NSExtensionMain: either the binary's own (LiveProcess
        defines one) or Foundation's, reached through an import stub."""
        entry = image.entry_offset
        if entry is None:
            return False
        if image.export_offsets().get('_NSExtensionMain') == entry:
            return True
        return any(sect in ('__stubs', '__auth_stubs') and offset <= entry < offset + size
                   for _, sect, offset, size in image.sections())

    def plists(self):
        print('Info.plist')
        app_info = None
        repo = self.repo
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
            if info.get('DTPlatformVersion') != self.args.sdk or info.get('DTSDKName') != f'iphoneos{self.args.sdk}':
                problems.append(f'SDK {info.get("DTSDKName")}, expected iphoneos{self.args.sdk}')
            problems += [f'{k} is not a dictionary' for k, v in info.items() if k.endswith('Dictionary')
                         and not isinstance(v, dict) and k not in self.template_keys(bundle)]
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
            if not bundle.endswith('.framework'):  # frameworks keep their module names
                self.old_names += [f'{rel}: {k}' for k, v in info.items()
                                   if (k in VISIBLE_KEYS or k.endswith('UsageDescription')) and says_old_name(v)]
            self.expect(not problems, f'{rel}: {info.get("CFBundleIdentifier")} {info.get("CFBundleShortVersionString")}'
                        f' ({info.get("CFBundleVersion")})', ', '.join(problems))
        if app_info is None:
            return self.fail('Info.plist: missing')
        self.app_info = app_info
        self.expect(app_info.get('CFBundleIdentifier') == self.args.bundle_id, f'app bundle ID {self.args.bundle_id}',
                    str(app_info.get('CFBundleIdentifier')))
        name = self.args.display_name or NAME
        self.expect(app_info.get('CFBundleDisplayName') == name, f'display name "{name}"',
                    str(app_info.get('CFBundleDisplayName')))
        self.expect(str(app_info.get('LCVersionInfo', '')).startswith('Release ('), f'LCVersionInfo "{app_info.get("LCVersionInfo")}"')
        self.expect(app_info.get('ZeusCompanion') == ZEUS_COMPANION, f'ZeusCompanion marker {ZEUS_COMPANION}',
                    str(app_info.get('ZeusCompanion')))
        icons = app_info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconFiles', [])
        icons += app_info.get('CFBundleIcons~ipad', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconFiles', [])
        icons.append(app_info.get('CFBundleIconFile', ''))
        names = os.listdir(self.app)
        lacking = [i for i in icons if not any(n.startswith(i) and n.endswith('.png') for n in names)]
        self.expect(icons and not lacking and 'CFBundleIconName' not in app_info,
                    f'icons {sorted(set(icons))} are loose PNGs', ', '.join(lacking))
        intents = os.path.join(self.app, 'PlugIns', 'LaunchAppExtension.appex', 'Metadata.appintents')
        if os.path.isdir(intents):
            try:
                with open(os.path.join(intents, 'extract.actionsdata'), encoding='utf-8') as f:
                    metadata = json.load(f)
                actions = sorted(metadata['actions'])
                self.old_names += [f'LaunchAppExtension Metadata.appintents: "{text[:40]}"'
                                   for text in strings_in(metadata) if says_old_name(text)]
                with open(os.path.join(intents, 'version.json'), encoding='utf-8') as f:
                    version = json.load(f)['version']
                self.ok(f'LaunchAppExtension Metadata.appintents: version {version}, actions {actions}')
            except (OSError, ValueError, KeyError) as e:
                self.fail(f'LaunchAppExtension Metadata.appintents does not parse ({e})')

    def identity(self):
        """zContainer's own URL scheme, name, keychain groups and app group, and no
        user-facing string left that says LiveContainer."""
        print('identity')
        info = getattr(self, 'app_info', None)
        if info is None:
            return self.fail('no main Info.plist to check')
        schemes = [s for t in info.get('CFBundleURLTypes', []) for s in t.get('CFBundleURLSchemes', [])]
        queried = info.get('LSApplicationQueriesSchemes', [])
        # LiveContainer reads its own scheme as the first one; Zeus adds its scheme after it.
        self.expect(schemes[:1] == [SCHEME], f'first URL scheme {SCHEME}://', ', '.join(schemes))
        old = [s for s in schemes + queried if OLD_NAME.search(s)]
        self.expect(not old, 'no livecontainer URL scheme declared or queried', ', '.join(old))
        self.expect(queried == QUERIED_SCHEMES, f'queried schemes {", ".join(QUERIED_SCHEMES)}', ', '.join(queried))
        self.expect(info.get('CFBundleName') == NAME, f'CFBundleName "{NAME}"', str(info.get('CFBundleName')))
        wanted_groups = [KEYCHAIN_GROUP] + [f'{KEYCHAIN_GROUP}.{i}' for i in range(1, KEYCHAIN_GROUP_COUNT)]
        app_group = f'group.{self.args.bundle_id}'
        for target in sorted(self.signer.targets):
            entitlements = self.signer.entitlements(target)
            if entitlements is None:
                continue
            groups = entitlements.get('keychain-access-groups')
            if groups is not None:
                teams = {g.split('.', 1)[0] for g in groups}
                suffixes = [g.split('.', 1)[1] for g in groups]
                self.expect(len(teams) == 1 and suffixes == wanted_groups,
                            f'{target}: {len(groups)} keychain groups <team>.{KEYCHAIN_GROUP}, .1 to .{KEYCHAIN_GROUP_COUNT - 1}',
                            ', '.join(sorted(set(suffixes) ^ set(wanted_groups))[:5]))
            app_groups = entitlements.get('com.apple.security.application-groups')
            if app_groups is not None:
                self.expect(app_groups == [app_group], f'{target}: app group {app_group}', ', '.join(app_groups))
        self.expect(not self.old_names, 'no user-facing string says LiveContainer (credits and links to it aside)',
                    ', '.join(self.old_names[:10]) + (f' and {len(self.old_names) - 10} more'
                                                      if len(self.old_names) > 10 else ''))

    def template_keys(self, bundle):
        """Keys the target's own Info.plist file sets (upstream's choices, kept as
        they are), as opposed to the ones the build adds."""
        target = 'LiveContainer' if bundle == '' else os.path.splitext(os.path.basename(bundle))[0]
        if target not in self.signer.targets:
            return set()
        template = self.signer.project.settings(target).get('INFOPLIST_FILE')
        if not template:
            return set()
        with open(os.path.join(self.repo, template), 'rb') as f:
            return set(plistlib.load(f))

    def strings(self):
        print('localization')
        tables = {}
        stores = []
        for entry in sorted(os.listdir(self.app)):
            path = os.path.join(self.app, entry, 'Localizable.strings')
            if entry.endswith('.lproj') and os.path.isfile(path):
                with open(path, 'rb') as f:
                    table = plistlib.load(f)
                tables[entry[:-6]] = set(table)
                dict_path = path + 'dict'
                if os.path.isfile(dict_path):
                    with open(dict_path, 'rb') as f:
                        plurals = plistlib.load(f)
                    tables[entry[:-6]] |= set(plurals)
                    table = {**table, **plurals}
                stores += [f'{entry}: {k}' for k, v in table.items() if STORES.search(k + repr(v))]
                self.old_names += [f'{entry}/Localizable: {k}' for k, v in table.items()
                                   if not k.startswith(CREDIT_KEYS) and says_old_name(v)]
        if not self.expect('en' in tables, 'en.lproj/Localizable.strings'):
            return
        short = {lang: len(tables['en'] - keys) for lang, keys in tables.items() if tables['en'] - keys}
        self.expect(not short, f'{len(tables)} languages, each with all {len(tables["en"])} keys', str(short))
        self.expect(not stores, 'no string mentions SideStore or AltStore', ', '.join(stores[:10]))
        infoplist = [e for e in os.listdir(self.app) if os.path.isfile(os.path.join(self.app, e, 'InfoPlist.strings'))]
        for entry in infoplist:
            with open(os.path.join(self.app, entry, 'InfoPlist.strings'), 'rb') as f:
                table = plistlib.load(f)
            self.old_names += [f'{entry}/InfoPlist: {k}' for k, v in table.items() if says_old_name(v)]
        self.ok(f'{len(infoplist)} InfoPlist.strings')


def main():
    env = os.environ
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('path', help='LiveContainer.app or an .ipa')
    parser.add_argument('--bundle-id', default=env.get('ZC_BUNDLE_ID', 'app.reiko.zcontainer'))
    parser.add_argument('--extensions', default=env.get('ZC_EXTENSIONS', '1'), choices=['0', '1'])
    parser.add_argument('--display-name', default=env.get('ZC_DISPLAY_NAME', ''))
    parser.add_argument('--min-ios', default=env.get('ZC_MIN_IOS', '17.0'))
    parser.add_argument('--sdk', default=env.get('ZC_RECORDED_SDK', '26.2'), help='SDK version the binaries record')
    parser.add_argument('--signing', choices=['adhoc', 'none', 'other'],
                        default='none' if env.get('ZC_ADHOC_SIGN') == '0' else 'adhoc',
                        help='adhoc: the build\'s own signatures; none: unsigned; other: re-signed by another tool')
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
        checker.identity()
    finally:
        if tmp:
            shutil.rmtree(tmp)
    if checker.failures:
        sys.exit(f'error: {checker.failures} check(s) failed')
    print('All checks passed')


if __name__ == '__main__':
    main()
