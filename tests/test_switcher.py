import tempfile
import unittest
from pathlib import Path

from codex_provider_switcher import Switcher, parse_args


class SwitcherTests(unittest.TestCase):
    def test_cli_mode_is_optional(self):
        self.assertIsNone(parse_args([]).mode)
        self.assertEqual(parse_args(["status"]).mode, "status")

    def test_top_level_config_values(self):
        original = 'model = "old"\n\n[features]\nflag = true\n'
        updated = Switcher.set_top_level_string(original, "model", "new")
        self.assertEqual(Switcher.get_top_level_value(updated, "model"), "new")
        self.assertIn("[features]", updated)

    def test_provider_block_is_replaced(self):
        original = '[model_providers.apimaster]\nbase_url = "old"\n\n[features]\nflag = true\n'
        updated = Switcher.upsert_apimaster_provider(original, "https://example.com/v1", False)
        self.assertEqual(updated.count("[model_providers.apimaster]"), 1)
        self.assertIn('base_url = "https://example.com/v1"', updated)
        self.assertIn("[features]", updated)

    def test_status_with_empty_codex_home(self):
        with tempfile.TemporaryDirectory() as directory:
            switcher = Switcher(Path(directory))
            switcher.status()


if __name__ == "__main__":
    unittest.main()
