import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location('strip_extensions', Path(__file__).resolve().parents[1] / 'scripts/strip_extensions.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StripExtensionsTest(unittest.TestCase):
    def test_removes_legacy_and_lock_screen_extensions_preserving_app(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'original.ipa'
            target = Path(directory) / 'fixed.ipa'
            retained = {
                'Payload/Instagram.app/Instagram': b'main executable',
                'Payload/Instagram.app/Frameworks/SCInsta.dylib': b'tweak',
                'Payload/Instagram.app/Info.plist': b'app metadata',
                'Payload/Instagram.app/Resources/Extensions/help.txt': b'ordinary resource',
            }
            with zipfile.ZipFile(source, 'w') as archive:
                for name, content in retained.items():
                    archive.writestr(name, content)
                archive.writestr('Payload/Instagram.app/PlugIns/Share.appex/Info.plist', b'legacy')
                archive.writestr('Payload/Instagram.app/Extensions/Camera.appex/Info.plist', b'camera')
            with self.assertRaises(ValueError):
                module.check(source)
            module.strip(source, target)
            module.check(target)
            with zipfile.ZipFile(target) as archive:
                self.assertEqual({name: archive.read(name) for name in archive.namelist()}, retained)
            with zipfile.ZipFile(source) as archive:
                self.assertEqual(len(archive.namelist()), len(retained) + 2)


if __name__ == '__main__':
    unittest.main()
