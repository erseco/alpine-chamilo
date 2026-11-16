import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('select_release', Path(__file__).resolve().parents[1] / 'scripts/select-release.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def release(version, **kwargs):
    return {'tag_name': f'v{version}', 'draft': False, 'prerelease': False,
            'assets': [{'name': f'chamilo-{version}.zip', 'state': 'uploaded', 'digest': 'sha256:' + 'a' * 64}], **kwargs}


class ReleaseSelectionTests(unittest.TestCase):
    def test_selects_latest_compatible_stable_release(self):
        releases = [release('3.0.3'), release('3.2.0'), release('3.10.0'), release('4.0.0'),
                    release('3.11.0', prerelease=True), release('3.12.0', draft=True)]
        self.assertEqual(module.select(releases, '3.0.2'), ((3, 10, 0), 'a' * 64))

    def test_requires_exact_uploaded_asset_and_sha256(self):
        invalid = release('3.0.3')
        invalid['assets'][0]['digest'] = None
        self.assertIsNone(module.select([invalid, release('3.0.2')], '3.0.2'))
        invalid['assets'][0]['digest'] = 'sha256:' + 'a' * 64
        invalid['assets'][0]['state'] = 'new'
        self.assertIsNone(module.select([invalid], '3.0.2'))

    def test_rejects_prerelease_and_noncanonical_tags(self):
        self.assertIsNone(module.select([release('3.1.0-rc1'), release('3.01.0'), release('2.0.0')], '3.0.2'))


if __name__ == '__main__':
    unittest.main()
