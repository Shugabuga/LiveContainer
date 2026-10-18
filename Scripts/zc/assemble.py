#!/usr/bin/env python3
"""Turns the binaries build.sh linked into a complete LiveContainer.app, doing the
resource steps Xcode would:

- Info.plist for the app and every framework and extension in it, with the build
  variables filled in from project.pbxproj and its xcconfig files, the
  INFOPLIST_KEY_* settings merged for targets that generate their Info.plist, and
  the keys Xcode adds to every bundle (MinimumOSVersion, platform, device family).
- Localizable.xcstrings compiled into <lang>.lproj/Localizable.strings and
  .stringsdict, with English filling in any string a language is missing.
- The app's resources from the Resources folder, the *.lproj folders the Xcode Run
  Script copies, and LCVersionInfo, which that script adds.
- No asset catalog compiler exists on Linux, so the app icon and images become loose
  PNG files. Asset catalog colors are skipped (the code falls back to system colors).
- The prebuilt OpenSSL and CydiaSubstrate frameworks, without headers.

Settings come from the environment (see env.sh): ZC_REPO, ZC_BUNDLE_ID,
ZC_DISPLAY_NAME, ZC_MIN_IOS, ZC_SDK, ZC_SDK_VERSION, ZC_OPENSSL, ZC_VERSION_INFO.

Usage: assemble.py <path to LiveContainer.app>
"""
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True  # keep __pycache__ out of the source tree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbxproj  # noqa: E402

ENV = os.environ
REPO = ENV['ZC_REPO']
MIN_IOS = ENV['ZC_MIN_IOS']
SDK_VERSION = ENV['ZC_SDK_VERSION']
PROJECT = pbxproj.Project(REPO)
# The app's bundle ID comes from this xcconfig variable; extensions append to it.
OVERRIDES = {'LIVECONTAINER_BUNDLE_IDENTIFIER': ENV['ZC_BUNDLE_ID']}
PACKAGE_TYPES = {
    'com.apple.product-type.application': 'APPL',
    'com.apple.product-type.framework': 'FMWK',
    'com.apple.product-type.app-extension': 'XPC!',
    'com.apple.product-type.extensionkit-extension': 'XPC!',
}


def fail(message):
    sys.exit(f'error: {message}')


def note(message):
    print(f'  {message}')


def write_plist(path, data):
    with open(path, 'wb') as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY, sort_keys=True)


def read_plist(path):
    with open(path, 'rb') as f:
        return plistlib.load(f)


# Info.plist

def sdk_build():
    try:
        return read_plist(os.path.join(ENV['ZC_SDK'], 'System/Library/CoreServices/SystemVersion.plist'))['ProductBuildVersion']
    except (OSError, KeyError):
        return None


SDK_BUILD = sdk_build()


def substitute(value, settings):
    if isinstance(value, str):
        return settings.expand(value)
    if isinstance(value, list):
        return [substitute(v, settings) for v in value]
    if isinstance(value, dict):
        return {k: substitute(v, settings) for k, v in value.items()}
    return value


def infoplist_keys(settings):
    """The INFOPLIST_KEY_* build settings as Info.plist entries, typed the way
    Xcode types them."""
    out = {}
    for name in settings.keys():
        if not name.startswith('INFOPLIST_KEY_'):
            continue
        key = name[len('INFOPLIST_KEY_'):]
        value = settings.get(name, '')
        if value == '':
            continue  # Xcode leaves out empty values
        if key.endswith('_Generation'):
            fail(f'{name} is not supported by assemble.py yet; add it')
        key = re.sub(r'_iPad$', '~ipad', re.sub(r'_iPhone$', '~iphone', key))
        if key.startswith('UISupportedInterfaceOrientations'):
            value = value.split()
        elif value in ('YES', 'NO'):
            value = value == 'YES'
        out[key] = value
    return out


def bundle_keys(settings):
    """Keys Xcode adds to every bundle's Info.plist when it processes it."""
    keys = {
        'CFBundleSupportedPlatforms': ['iPhoneOS'],
        'MinimumOSVersion': MIN_IOS,
        'UIDeviceFamily': [int(x) for x in settings.get('TARGETED_DEVICE_FAMILY', '1,2').split(',')],
        'DTPlatformName': 'iphoneos',
        'DTPlatformVersion': SDK_VERSION,
        'DTSDKName': f'iphoneos{SDK_VERSION}',
    }
    if SDK_BUILD:
        keys['DTSDKBuild'] = SDK_BUILD
    return keys


def make_info_plist(target_name, bundle_dir):
    target = PROJECT.target(target_name)
    settings = PROJECT.settings(target_name, OVERRIDES)
    package_type = PACKAGE_TYPES[target['productType']]
    info = {}
    if settings.get('GENERATE_INFOPLIST_FILE') == 'YES':
        info.update({
            'CFBundleDevelopmentRegion': settings.get('DEVELOPMENT_LANGUAGE'),
            'CFBundleExecutable': settings.get('EXECUTABLE_NAME'),
            'CFBundleIdentifier': settings.get('PRODUCT_BUNDLE_IDENTIFIER'),
            'CFBundleInfoDictionaryVersion': '6.0',
            'CFBundleName': settings.get('PRODUCT_NAME'),
            'CFBundlePackageType': package_type,
            'CFBundleShortVersionString': settings.get('MARKETING_VERSION'),
            'CFBundleVersion': settings.get('CURRENT_PROJECT_VERSION'),
        })
        info.update(infoplist_keys(settings))
    template = settings.get('INFOPLIST_FILE')
    if template:
        info.update(substitute(read_plist(os.path.join(REPO, template)), settings))
    info.update(bundle_keys(settings))
    exe = info.get('CFBundleExecutable')
    if not exe or not os.path.isfile(os.path.join(bundle_dir, exe)):
        fail(f'{bundle_dir}: CFBundleExecutable {exe!r} was not built')
    return info


def main_app_plist(app):
    info = make_info_plist('LiveContainer', app)
    # No Assets.car: name loose icon files the way actool lists them, keeping the
    # array shapes LCUtils.m edits for the grey multi-LiveContainer icon.
    info.pop('CFBundleIconName', None)
    info['CFBundleIcons'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60']}}
    info['CFBundleIcons~ipad'] = {'CFBundlePrimaryIcon': {'CFBundleIconFiles': ['AppIcon60x60', 'AppIcon76x76']}}
    info['CFBundleIconFile'] = 'AppIcon'
    # What the Xcode target's Run Script adds: "$CONFIGURATION ($BRANCH/$COMMIT)".
    info['LCVersionInfo'] = ENV.get('ZC_VERSION_INFO') or 'Release (unknown/unknown)'
    if ENV.get('ZC_DISPLAY_NAME'):
        info['CFBundleDisplayName'] = ENV['ZC_DISPLAY_NAME']
    write_plist(os.path.join(app, 'Info.plist'), info)
    with open(os.path.join(app, 'PkgInfo'), 'w') as f:
        f.write('APPL????')
    note(f'Info.plist: {info["CFBundleIdentifier"]}, "{info.get("CFBundleDisplayName")}", {info["LCVersionInfo"]}')


def nested_bundles(app):
    """(target name, bundle path) for every framework and extension build.sh made."""
    out = []
    for folder, suffix in (('Frameworks', '.framework'), ('PlugIns', '.appex'), ('Extensions', '.appex')):
        root = os.path.join(app, folder)
        if not os.path.isdir(root):
            continue
        for entry in sorted(os.listdir(root)):
            if entry.endswith(suffix) and entry[:-len(suffix)] in {t['name'] for t in PROJECT.targets()}:
                out.append((entry[:-len(suffix)], os.path.join(root, entry)))
    return out


# Prebuilt frameworks, embedded the way Xcode's "Remove Headers on Copy" does.

def copy_prebuilt(app):
    prebuilt = [os.path.join(ENV['ZC_OPENSSL'], 'OpenSSL.framework'),  # OpenSSL.xcframework's ios-arm64 slice
                os.path.join(REPO, 'Resources/Frameworks/CydiaSubstrate.framework')]
    for src in prebuilt:
        dst = os.path.join(app, 'Frameworks', os.path.basename(src))
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns('Headers', 'PrivateHeaders', 'Modules', '_CodeSignature'))
        note(f'Frameworks/{os.path.basename(src)} (prebuilt)')


# String catalog

FORMAT_SPEC = re.compile(r'%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(hh|h|ll|l|q|z|t|j)?([@dDuUxXoOfeEgGcCsSpaA])')


def value_type(text, key):
    found = FORMAT_SPEC.findall(text)
    if len(found) != 1:
        fail(f'Localizable.xcstrings: plural form of {key!r} needs exactly one format specifier, has {len(found)}')
    return ''.join(found[0])


def plural_forms(variations, key):
    if set(variations) != {'plural'}:
        fail(f'Localizable.xcstrings: {key!r} uses {sorted(variations)} variations; only plural is supported')
    return {form: v['stringUnit']['value'] for form, v in variations['plural'].items()}


def compile_entry(key, loc):
    """One catalog localization as ('strings', text) or ('stringsdict', dict)."""
    if 'variations' in loc:
        forms = plural_forms(loc['variations'], key)
        spec = value_type(forms.get('other') or next(iter(forms.values())), key)
        return 'stringsdict', {
            'NSStringLocalizedFormatKey': '%#@value@',
            'value': {'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType', 'NSStringFormatValueTypeKey': spec, **forms},
        }
    text = loc['stringUnit']['value']
    if 'substitutions' not in loc:
        return 'strings', text
    entry = {}
    for name, sub in loc['substitutions'].items():
        num, spec = sub.get('argNum', 1), sub.get('formatSpecifier', 'lld')
        forms = plural_forms(sub['variations'], key)
        entry[name] = {'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType', 'NSStringFormatValueTypeKey': spec,
                       **{f: t.replace('%arg', f'%{num}${spec}') for f, t in forms.items()}}
        text = re.sub(r'%#@' + re.escape(name) + '@', f'%{num}$#@{name}@', text)
    entry['NSStringLocalizedFormatKey'] = text
    return 'stringsdict', entry


def compile_string_catalog(app, path):
    with open(path, encoding='utf-8') as f:
        catalog = json.load(f)
    source = catalog.get('sourceLanguage', 'en')
    entries = catalog['strings']
    languages = sorted({lang for e in entries.values() for lang in e.get('localizations', {})} | {source})
    fallbacks = []
    for lang in languages:
        strings, plurals, filled = {}, {}, 0
        for key, entry in entries.items():
            locs = entry.get('localizations', {})
            loc = locs.get(lang)
            if loc is None:
                loc = locs.get(source)
                filled += 1
            if loc is None:
                strings[key] = key  # Xcode's fallback for a key nobody localized
                continue
            kind, value = compile_entry(key, loc)
            (strings if kind == 'strings' else plurals)[key] = value
        folder = os.path.join(app, f'{lang}.lproj')
        os.makedirs(folder, exist_ok=True)
        write_plist(os.path.join(folder, 'Localizable.strings'), strings)
        if plurals:
            write_plist(os.path.join(folder, 'Localizable.stringsdict'), plurals)
        if filled and lang != source:
            fallbacks.append(f'{lang} {filled}')
    note(f'{os.path.basename(path)}: {len(entries)} keys in {len(languages)} languages')
    if fallbacks:
        note(f'untranslated strings filled in from {source}: {", ".join(fallbacks)}')


# Asset catalog (no actool on Linux)

def magick(*args):
    tool = shutil.which('magick') or shutil.which('convert')
    subprocess.run([tool, *args], check=True)


def app_icon_source(appiconset):
    with open(os.path.join(appiconset, 'Contents.json'), encoding='utf-8') as f:
        images = json.load(f)['images']
    for image in images:
        if image.get('filename') and not image.get('appearances') and image.get('idiom') in ('universal', 'ios-marketing'):
            return os.path.join(appiconset, image['filename'])
    fail(f'{appiconset}: no light-appearance universal icon')


def compile_asset_catalog(app, catalog, icon_name):
    skipped = []
    for entry in sorted(os.listdir(catalog)):
        path = os.path.join(catalog, entry)
        name, kind = os.path.splitext(entry)
        if kind == '.appiconset' and name == icon_name:
            src = app_icon_source(path)
            for out, px in (('AppIcon60x60@2x.png', 120), ('AppIcon60x60@3x.png', 180),
                            ('AppIcon76x76@2x~ipad.png', 152), ('AppIcon.png', 1024)):
                magick(src, '-resize', f'{px}x{px}', '-strip', os.path.join(app, out))
            note(f'{entry}: loose AppIcon PNGs (no dark or tinted variants without Assets.car)')
        elif kind == '.imageset':
            with open(os.path.join(path, 'Contents.json'), encoding='utf-8') as f:
                images = json.load(f)['images']
            for image in images:
                if 'filename' not in image:
                    continue
                scale = image.get('scale', '1x')
                out = os.path.join(app, f'{name}.png' if scale == '1x' else f'{name}@{scale}.png')
                if not os.path.exists(out):
                    shutil.copyfile(os.path.join(path, image['filename']), out)
        elif kind in ('.colorset', '.appiconset'):
            skipped.append(entry)
        elif os.path.isdir(path):
            fail(f'{path}: assemble.py does not handle {kind or "folder"} entries in asset catalogs')
    if skipped:
        note(f'skipped (needs Assets.car): {", ".join(skipped)}')


# The app's resources, as the Xcode project assigns them.

def app_resources():
    """Files in synced folders that the Xcode project adds to the LiveContainer
    target (the Resources folder belongs to no target and lists its members)."""
    app_target = PROJECT.target('LiveContainer')
    owned = {g for t in PROJECT.targets() for g in t.get('fileSystemSynchronizedGroups', [])}
    out = []
    for ident, o in PROJECT.objects.items():
        if o['isa'] != 'PBXFileSystemSynchronizedRootGroup' or ident in owned:
            continue
        for ex in o.get('exceptions', []):
            ex = PROJECT.obj(ex)
            if ex['isa'] == 'PBXFileSystemSynchronizedBuildFileExceptionSet' and \
                    PROJECT.obj(ex['target']) is app_target:
                out += [os.path.join(REPO, o['path'], m) for m in ex['membershipExceptions']]
    return out


def copy_resources(app):
    settings = PROJECT.settings('LiveContainer', OVERRIDES)
    icon_name = settings.get('ASSETCATALOG_COMPILER_APPICON_NAME', 'AppIcon')
    for src in app_resources():
        name = os.path.basename(src)
        if name.endswith('.xcassets'):
            compile_asset_catalog(app, src, icon_name)
        elif name.endswith('.xcstrings'):
            compile_string_catalog(app, src)
        elif os.path.isdir(src):
            shutil.copytree(src, os.path.join(app, name), dirs_exist_ok=True)
        else:
            shutil.copyfile(src, os.path.join(app, name))
    # The Run Script's `cp -n -r Resources/*.lproj`: InfoPlist.strings for each language.
    res = os.path.join(REPO, 'Resources')
    for entry in sorted(os.listdir(res)):
        if entry.endswith('.lproj'):
            for root, _, files in os.walk(os.path.join(res, entry)):
                dst_dir = os.path.join(app, os.path.relpath(root, res))
                os.makedirs(dst_dir, exist_ok=True)
                for f in files:
                    if not os.path.exists(os.path.join(dst_dir, f)):
                        shutil.copyfile(os.path.join(root, f), os.path.join(dst_dir, f))


def check_no_variables(app):
    bad = []
    for root, _, files in os.walk(app):
        for f in files:
            if f == 'Info.plist':
                path = os.path.join(root, f)
                if re.search(rb'\$[({][A-Za-z_]', open(path, 'rb').read()):
                    bad.append(os.path.relpath(path, app))
    if bad:
        fail('unresolved $(...) build variables left in ' + ', '.join(bad))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip())
    app = os.path.abspath(sys.argv[1])
    copy_prebuilt(app)
    for target_name, bundle in nested_bundles(app):
        info = make_info_plist(target_name, bundle)
        write_plist(os.path.join(bundle, 'Info.plist'), info)
        note(f'{os.path.relpath(bundle, app)}: {info["CFBundleIdentifier"]}')
    copy_resources(app)
    main_app_plist(app)
    check_no_variables(app)


if __name__ == '__main__':
    main()
