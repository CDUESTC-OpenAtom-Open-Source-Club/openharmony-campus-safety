"""Sync the freshly compiled HAP into the native Android Gradle source tree.
Run Gradle after this step: resource-only APK repackaging cannot add native bridges.
"""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
hap = root / 'entry/build/default/outputs/default/entry-default-unsigned.hap'
metadata = root / 'entry/build/default/intermediates/res/default/ark_module.json'
asset_root = root / '.arkui-x/android/app/src/main/assets/arkui-x'
assert asset_root.resolve().is_relative_to(root)
with zipfile.ZipFile(hap) as package:
    names = [name for name in package.namelist() if not name.endswith('/') and
             (name in ('module.json', 'resources.index') or name.startswith(('ets/', 'resources/')))]
    assert 'ets/modules.abc' in names and 'module.json' in names
    for folder in ('entry', 'entryTest'):
        target = (asset_root / folder).resolve()
        assert target.parent == asset_root.resolve() and target.is_relative_to(root)
        if target.exists():
            shutil.rmtree(target)
    for name in names:
        target = (asset_root / 'entry' / name).resolve()
        assert target.is_relative_to((asset_root / 'entry').resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(package.read(name))
    (asset_root / 'entry/ark_module.json').write_bytes(metadata.read_bytes())
    print(json.dumps({'assets': len(names) + 1, 'test_assets_removed': True,
                      'modules_abc_sha256': hashlib.sha256(package.read('ets/modules.abc')).hexdigest()}))
