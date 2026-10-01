"""Verify reversible profile changes without touching real configs or runtimes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('terminal_buddie', Path(__file__).resolve().parents[1] / 'scripts/terminal-buddie.py')
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)

CONFIG = '''model = "unchanged"
[mcp_servers.cua]
command = "/usr/bin/python3"
args = ["/existing/official-launch.py"]
tool_timeout_sec = 120
enabled_tools = ["js", "js_reset", "turn_ended"]

[mcp_servers.cua.tools.js]
output_token_limit = 25000
[mcp_servers.other]
command = "keep-me"
'''


class TerminalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.main = self.home / '.codex/config.toml'
        self.orca = self.home / 'Library/Application Support/orca/codex-accounts/account/home/config.toml'
        for path in [self.main, self.orca]:
            path.parent.mkdir(parents=True); path.write_text(CONFIG); path.chmod(0o600)
        self.service = self.home / 'Prepared Service.app'; self.service.mkdir()
        self.addCleanup(patch.stopall)
        patch.object(terminal, 'validate_service').start()
        patch.object(terminal, 'official_runtime', return_value=(Path('official'), {})).start()

    def test_enable_disable_preserves_other_settings_and_later_edits(self):
        result = terminal.enable(self.home, self.service)
        self.assertEqual(result['profiles'], 2)
        after = self.main.read_text()
        self.assertIn('enabled_tools = ["js", "js_reset", "turn_ended"]', after)
        self.assertEqual(after[after.index('[mcp_servers.cua.tools.js]'):], CONFIG[CONFIG.index('[mcp_servers.cua.tools.js]'):])
        self.assertEqual(self.main.stat().st_mode & 0o777, 0o600)
        self.main.write_text(after.replace('model = "unchanged"', 'model = "later-edit"'))
        terminal.disable(self.home)
        self.assertEqual(self.main.read_text(), CONFIG.replace('model = "unchanged"', 'model = "later-edit"'))
        self.assertEqual(self.orca.read_text(), CONFIG)

    def test_refuses_overwriting_a_changed_cua_stanza(self):
        terminal.enable(self.home, self.service)
        self.orca.write_text(self.orca.read_text().replace('tool_timeout_sec = 120', 'tool_timeout_sec = 240'))
        before = self.main.read_text()
        with self.assertRaisesRegex(ValueError, 'changed since activation'):
            terminal.disable(self.home)
        self.assertEqual(self.main.read_text(), before)

    def test_malformed_profile_does_not_partially_install(self):
        self.orca.write_text(CONFIG.replace('args = ["/existing/official-launch.py"]', 'args = [\n"/existing/official-launch.py"\n]'))
        with self.assertRaisesRegex(ValueError, 'single-line'):
            terminal.enable(self.home, self.service)
        self.assertEqual(self.main.read_text(), CONFIG)
        self.assertFalse((terminal.location(self.home) / 'terminal-state.json').exists())

    def test_write_failure_restores_profiles_already_changed(self):
        original = terminal.atomic
        def fail(path, text, mode=0o600):
            if path == self.orca: raise OSError('simulated write failure')
            return original(path, text, mode)
        with patch.object(terminal, 'atomic', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'simulated'):
                terminal.enable(self.home, self.service)
        self.assertEqual(self.main.read_text(), CONFIG)
        self.assertEqual(self.orca.read_text(), CONFIG)
        self.assertFalse(json.loads((terminal.location(self.home) / 'terminal-state.json').read_text())['active'])

    def test_refuses_double_enable_preserving_rollback(self):
        terminal.enable(self.home, self.service)
        state = (terminal.location(self.home) / 'terminal-state.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'Already enabled'):
            terminal.enable(self.home, self.service)
        self.assertEqual((terminal.location(self.home) / 'terminal-state.json').read_bytes(), state)

    def test_disable_can_resume_after_a_partial_write_failure(self):
        terminal.enable(self.home, self.service)
        original = terminal.atomic
        def fail(path, text, mode=0o600):
            if path == self.orca: raise OSError('simulated restore failure')
            return original(path, text, mode)
        with patch.object(terminal, 'atomic', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'simulated restore'):
                terminal.disable(self.home)
        self.assertEqual(self.main.read_text(), CONFIG)
        self.assertNotEqual(self.orca.read_text(), CONFIG)
        terminal.disable(self.home)
        self.assertEqual(self.orca.read_text(), CONFIG)


if __name__ == '__main__': unittest.main()
