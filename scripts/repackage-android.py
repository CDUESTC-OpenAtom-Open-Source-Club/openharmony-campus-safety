"""Package a current HAP into an existing, matching ArkUI-X Android runtime host.

This replaces every application asset, removes test assets/signatures, and disables
Android backup. It is asset repackaging, not a fresh Gradle/native-host build.
Native API compatibility and device acceptance require separate validation.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def disable_backup(raw: bytes) -> bytes:
    data = bytearray(raw)
    resource_ids = []
    offset = struct.unpack_from('<H', data, 2)[0]
    changed = 0
    while offset < len(data):
        kind, header_size, size = struct.unpack_from('<HHI', data, offset)
        if size < header_size or size == 0 or offset + size > len(data):
            raise ValueError('Invalid Android binary XML chunk')
        if kind == 0x0180:
            resource_ids = list(struct.unpack_from('<' + 'I' * ((size - header_size) // 4), data, offset + header_size))
        elif kind == 0x0102:
            ext = offset + header_size
            attr_start, attr_size, count = struct.unpack_from('<HHH', data, ext + 8)
            for index in range(count):
                attr = ext + attr_start + index * attr_size
                name = struct.unpack_from('<I', data, attr + 4)[0]
                if name < len(resource_ids) and resource_ids[name] == 0x01010280:
                    if data[attr + 15] != 0x12:
                        raise ValueError('allowBackup must be a literal boolean')
                    struct.pack_into('<I', data, attr + 8, 0xFFFFFFFF)
                    struct.pack_into('<I', data, attr + 16, 0)
                    changed += 1
        offset += size
    if changed != 1:
        raise ValueError(f'Expected one allowBackup attribute, got {changed}')
    return bytes(data)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', type=Path, required=True)
    parser.add_argument('--hap', type=Path, required=True)
    parser.add_argument('--ark-module', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    assert args.output.resolve() not in (args.host.resolve(), args.hap.resolve())
    prefix = 'assets/arkui-x/entry/'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.host) as host, zipfile.ZipFile(args.hap) as hap:
        old_meta = json.loads(host.read(prefix + 'ark_module.json'))
        new_meta = json.loads(args.ark_module.read_text(encoding='utf-8'))
        for key in ('bundleName', 'compileSdkVersion'):
            if old_meta['app'][key] != new_meta['app'][key]:
                raise ValueError(f'Runtime-host mismatch: {key}')
        expected = {name: hap.read(name) for name in hap.namelist()
                    if name in ('module.json', 'resources.index') or name.startswith(('ets/', 'resources/'))}
        assert 'ets/modules.abc' in expected and 'module.json' in expected
        with zipfile.ZipFile(args.output, 'w') as output:
            for item in host.infolist():
                if item.filename.startswith((prefix, 'assets/arkui-x/entryTest/', 'META-INF/')):
                    continue
                content = host.read(item.filename)
                if item.filename == 'AndroidManifest.xml':
                    content = disable_backup(content)
                output.writestr(copy.copy(item), content)
            for name, content in expected.items():
                output.writestr(prefix + name, content, compress_type=zipfile.ZIP_DEFLATED)
            output.writestr(prefix + 'ark_module.json', args.ark_module.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
        with zipfile.ZipFile(args.output) as check:
            assert check.testzip() is None
            assert all(check.read(prefix + name) == content for name, content in expected.items())
            assert not any(name.startswith('assets/arkui-x/entryTest/') for name in check.namelist())
            for name in host.namelist():
                if name.startswith('lib/') or name.endswith('.dex'):
                    assert check.read(name) == host.read(name)
        print(json.dumps({'output': str(args.output.resolve()), 'bytes': args.output.stat().st_size,
                          'sha256': sha(args.output), 'source_hap_sha256': sha(args.hap),
                          'host_apk_sha256': sha(args.host),
                          'modules_abc_sha256': hashlib.sha256(expected['ets/modules.abc']).hexdigest(),
                          'application_assets_replaced': len(expected) + 1,
                          'test_assets_removed': True, 'android_backup_disabled': True,
                          'native_host_rebuilt': False}, indent=2))


if __name__ == '__main__':
    main()
