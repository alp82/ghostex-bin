import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('update', Path(__file__).resolve().parents[1] / 'scripts/update.py')
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)


def release(version='9.1.0'):
    name = f'ghostex-{version}-linux-x64.tar.zst'
    return {'tag_name': f'v{version}', 'draft': False, 'prerelease': False,
            'assets': [{'name': name, 'browser_download_url':
                        f'https://github.com/maddada/Ghostex/releases/download/v{version}/{name}'}]}


class ReleaseSelection(unittest.TestCase):
    def test_new_stable_release(self):
        self.assertEqual(update.select_release(release('10.0.0'), '9.0.0')[0], '10.0.0')

    def test_same_version_and_downgrades_are_noops(self):
        for version in ['9.0.0', '8.9.0']:
            self.assertIsNone(update.select_release(release(version), '9.0.0'))

    def test_incomplete_release_is_retried_without_changing_recipe(self):
        data = release()
        data['assets'] = []
        with self.assertRaises(ValueError):
            update.select_release(data, '9.0.0')

    def test_rejects_prerelease_and_draft(self):
        for field in ['draft', 'prerelease']:
            data = release()
            data[field] = True
            with self.assertRaises(ValueError):
                update.select_release(data, '9.0.0')

    def test_rejects_unexpected_asset_origin(self):
        data = release()
        data['assets'][0]['browser_download_url'] = 'https://example.com/replaced.tar.zst'
        with self.assertRaises(ValueError):
            update.select_release(data, '9.0.0')

    def test_rejects_shell_syntax_and_unsupported_version_formats(self):
        for version in ['9.1.0;echo bad', '9.1.0-rc1', '9.1', '$(echo bad)']:
            with self.assertRaises(ValueError):
                update.select_release(release(version), '9.0.0')


if __name__ == '__main__':
    unittest.main()
