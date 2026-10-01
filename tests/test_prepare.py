"""Exercise preparation boundaries without accessing a signing key or vendor code."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location('buddie_prepare', SCRIPTS / 'prepare.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PreparationTests(unittest.TestCase):
    def exercise(self, identity):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source = root / 'vendor.app'
            executable = source / 'Contents/MacOS/SkyComputerUseService'
            executable.parent.mkdir(parents=True)
            original = b'original executable fixture'
            executable.write_bytes(original)
            (source / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.openai.sky.CUAService'}))
            (root / 'compatibility').mkdir()
            (root / 'compatibility/macos-arm64.json').write_text(json.dumps({hashlib.sha256(original).hexdigest(): {'status': 'fixture'}}))
            library = root / '.build/Codex Buddie Lab.app/Contents/Frameworks/libBuddie.dylib'
            library.parent.mkdir(parents=True); library.write_bytes(b'renderer fixture')
            pack=root / 'Characters/pip'; pack.mkdir(parents=True)
            (pack / 'buddy.json').write_text('{"version":2,"id":"pip"}')
            destination = root / 'isolated.app'
            with patch.object(prepare, 'ROOT', root), patch.object(prepare.platform, 'system', return_value='Darwin'), patch.object(prepare.platform, 'machine', return_value='arm64'), patch.object(prepare, 'inject', return_value=b'patched fixture'), patch.object(prepare.subprocess, 'run') as command, contextlib.redirect_stdout(io.StringIO()):
                prepare.prepare(source, destination, identity)
                self.assertEqual(executable.read_bytes(), original)
                self.assertEqual(plistlib.loads((source / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'], 'com.openai.sky.CUAService')
                self.assertEqual(plistlib.loads((destination / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'], 'ai.suture.codex-buddie.runtime')
                self.assertEqual((destination / 'Contents/Resources/BuddieCharacters/pip/buddy.json').read_bytes(),(pack / 'buddy.json').read_bytes())
                signs = [c.args[0] for c in command.call_args_list if '--sign' in c.args[0]]
                self.assertEqual(len(signs), 1 if identity == '-' else 2)
                for sign in signs:
                    self.assertTrue(Path(sign[-1]) == destination or destination in Path(sign[-1]).parents)
                    self.assertEqual(sign[sign.index('--sign')+1], identity)
                    self.assertEqual(sign[sign.index('--options')+1], '0' if identity == '-' else 'runtime')
                with self.assertRaises(ValueError):
                    prepare.prepare(source, destination, identity)

    def test_ad_hoc_preparation_keeps_original_unchanged(self):
        self.exercise('-')

    def test_development_preparation_signs_only_copy_with_runtime(self):
        self.exercise('local-development-fixture')


if __name__ == '__main__':
    unittest.main()
