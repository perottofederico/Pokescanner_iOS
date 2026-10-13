import argparse
import json
import plistlib
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_source():
    project = json.loads((ROOT / 'project.json').read_text(encoding='utf-8'))
    targets = project['targets']
    app = targets['PokeCapture']
    extension = targets['BroadcastUpload']
    app_settings = app['settings']['base']
    extension_settings = extension['settings']['base']
    require(app['type'] == 'application', 'Host must be an application.')
    require(extension['type'] == 'app-extension', 'Broadcast target must be an extension.')
    require(extension_settings['PRODUCT_BUNDLE_IDENTIFIER'].startswith(
        app_settings['PRODUCT_BUNDLE_IDENTIFIER'] + '.'
    ), 'Extension identifier must be nested under the host identifier.')
    require(any(dependency.get('target') == 'BroadcastUpload' and dependency.get('embed')
                for dependency in app['dependencies']), 'Host must embed the broadcast extension.')
    require(extension_settings['APPLICATION_EXTENSION_API_ONLY'] == 'YES',
            'Extension must only use extension-safe APIs.')
    require(project['settings']['base']['CODE_SIGNING_ALLOWED'] == 'NO',
            'The default build must not require Apple credentials.')
    for target in targets.values():
        for source in target['sources']:
            source_path = source['path'] if isinstance(source, dict) else source
            require((ROOT / source_path).is_dir(), f'Missing source directory: {source_path}')
        settings = target['settings']['base']
        require('CODE_SIGN_ENTITLEMENTS' not in settings,
                'Demo should not require restricted provisioning entitlements.')
        with (ROOT / settings['INFOPLIST_FILE']).open('rb') as plist_file:
            info = plistlib.load(plist_file)
        require(info['CFBundleIdentifier'] == '$(PRODUCT_BUNDLE_IDENTIFIER)',
                'Bundle identifier must follow the build settings.')
        require(info['CFBundleVersion'] == '$(CURRENT_PROJECT_VERSION)',
                'App and extension versions must use matching build settings.')
        if target['type'] == 'app-extension':
            validate_extension_info(info, '$(PRODUCT_MODULE_NAME).SampleHandler')
    print('PASS: project specification, plist files, embedding, and unsigned configuration.')


def validate_extension_info(info, principal_class):
    configuration = info['NSExtension']
    require(configuration['NSExtensionPointIdentifier'] == 'com.apple.broadcast-services-upload',
            'Wrong broadcast extension point.')
    require(configuration['NSExtensionPrincipalClass'] == principal_class,
            'Wrong broadcast sample handler class.')
    require(configuration['RPBroadcastProcessMode'] == 'RPBroadcastProcessModeSampleBuffer',
            'Broadcast extension must receive sample buffers.')


def validate_ipa(ipa_path):
    with zipfile.ZipFile(ipa_path) as archive:
        app_prefix = 'Payload/PokeCapture.app/'
        extension_prefix = app_prefix + 'PlugIns/BroadcastUpload.appex/'
        app_info = plistlib.loads(archive.read(app_prefix + 'Info.plist'))
        extension_info = plistlib.loads(archive.read(extension_prefix + 'Info.plist'))
        for prefix, info in [(app_prefix, app_info), (extension_prefix, extension_info)]:
            require(archive.getinfo(prefix + info['CFBundleExecutable']).file_size > 0,
                    'Compiled binary missing or empty.')
            require(info['CFBundleSupportedPlatforms'] == ['iPhoneOS'],
                    'IPA must contain device binaries, not simulator binaries.')
            require('$(' not in info['CFBundleIdentifier'], 'Unresolved bundle identifier.')
        require(extension_info['CFBundleIdentifier'].startswith(app_info['CFBundleIdentifier'] + '.'),
                'Packaged extension identifier must be nested under the host.')
        require(app_info['CFBundleVersion'] == extension_info['CFBundleVersion'],
                'Packaged app and extension build versions differ.')
        require(app_info['CFBundleShortVersionString'] == extension_info['CFBundleShortVersionString'],
                'Packaged app and extension marketing versions differ.')
        validate_extension_info(extension_info, 'BroadcastUpload.SampleHandler')
    print('PASS: IPA includes device app, executable broadcast extension, and resolved metadata.')


def main():
    parser = argparse.ArgumentParser(description='Validate capture-demo configuration and optional built IPA.')
    parser.add_argument('--ipa', type=Path)
    arguments = parser.parse_args()
    try:
        validate_source()
        if arguments.ipa:
            validate_ipa(arguments.ipa)
    except (OSError, KeyError, ValueError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
